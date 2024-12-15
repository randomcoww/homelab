locals {
  ports = {
    vnc = 6901
  }
  username = "kasm_user"
}

# bypassed through nginx - no need to expose
resource "random_password" "password" {
  length  = 16
  special = false
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.kasm)[1]
  manifests = {
    "templates/secret.yaml"      = module.secret.manifest
    "templates/service.yaml"     = module.service.manifest
    "templates/ingress.yaml"     = module.ingress.manifest
    "templates/statefulset.yaml" = module.statefulset.manifest
  }
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = merge({
    VNC_PW = random_password.password.result
  })
}

module "service" {
  source  = "../../../modules/service"
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = "vnc"
        port       = local.ports.vnc
        protocol   = "TCP"
        targetPort = local.ports.vnc
      },
    ]
  }
}

module "ingress" {
  source             = "../../../modules/ingress"
  name               = var.name
  app                = var.name
  release            = var.release
  ingress_class_name = var.ingress_class_name
  annotations = merge(var.nginx_ingress_annotations, {
    "nginx.ingress.kubernetes.io/backend-protocol"      = "HTTPS"
    "nginx.ingress.kubernetes.io/configuration-snippet" = <<-EOF
    proxy_set_header Authorization "Basic ${base64encode("${local.username}:${random_password.password.result}")}";
    EOF
  })
  rules = [
    {
      host = var.service_hostname
      paths = [
        {
          service = var.name
          port    = local.ports.vnc
          path    = "/"
        },
      ]
    },
  ]
}

module "statefulset" {
  source   = "../../../modules/statefulset"
  name     = var.name
  app      = var.name
  release  = var.release
  replicas = 1
  affinity = var.affinity
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  template_spec = {
    containers = [
      {
        name  = var.name
        image = var.images.kasm
        env = concat([
          {
            name = "VNC_PW"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = "VNC_PW"
              }
            }
          },
          ], [
          for _, e in var.kasm_extra_envs :
          {
            name  = e.name
            value = tostring(e.value)
          }
        ])
        volumeMounts = concat([
          {
            name      = "dshm"
            mountPath = "/dev/shm"
          },
        ], var.kasm_extra_volume_mounts)
        ports = [
          {
            containerPort = local.ports.vnc
          },
        ]
        readinessProbe = {
          tcpSocket = {
            port = local.ports.vnc
          }
        }
        livenessProbe = {
          tcpSocket = {
            port = local.ports.vnc
          }
        }
        securityContext = var.kasm_security_context
        resources       = var.kasm_resources
      },
    ]
    volumes = concat([
      {
        name = "dshm"
        emptyDir = {
          medium = "Memory"
        }
      },
    ], var.kasm_extra_volumes)
  }
}