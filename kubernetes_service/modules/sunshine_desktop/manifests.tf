locals {
  # https://docs.lizardbyte.dev/projects/sunshine/en/latest/about/advanced_usage.html#port
  home_path = "/home/${var.user}"
  base_port = 47989
  tcp_ports = {
    https = local.base_port - 5
    http  = local.base_port
    web   = local.base_port + 1
    rtsp  = local.base_port + 21
  }
  udp_ports = {
    video   = local.base_port + 9
    control = local.base_port + 10
    audio   = local.base_port + 11
    mic     = local.base_port + 13
  }
}

# bypassed through nginx - no need to expose
resource "random_password" "username" {
  length  = 16
  special = false
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
  app_version = split(":", var.images.sunshine_desktop)[1]
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
  data = {
    USERNAME = random_password.username.result
    PASSWORD = random_password.password.result
  }
}

module "service" {
  source  = "../../../modules/service"
  name    = var.name
  app     = var.name
  release = var.release
  annotations = {
    "external-dns.alpha.kubernetes.io/hostname" = var.service_hostname
  }
  spec = {
    type              = "LoadBalancer"
    loadBalancerIP    = var.service_ip
    loadBalancerClass = var.loadbalancer_class_name
    ports = concat([
      for name, port in local.tcp_ports :
      {
        name       = name
        port       = port
        protocol   = "TCP"
        targetPort = port
      }
      ], [
      for name, port in local.udp_ports :
      {
        name       = name
        port       = port
        protocol   = "UDP"
        targetPort = port
      }
    ])
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
    proxy_set_header Authorization "Basic ${base64encode("${random_password.username.result}:${random_password.password.result}")}";
    EOF
  })
  rules = [
    {
      host = var.admin_hostname
      paths = [
        {
          service = module.service.name
          port    = local.tcp_ports.web
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
  spec = {
    volumeClaimTemplates = [
      {
        metadata = {
          name = "home"
        }
        spec = {
          accessModes = [
            "ReadWriteOnce",
          ]
          resources = {
            requests = {
              storage = "600Gi"
            }
          }
          storageClassName = var.storage_class_name
        }
      },
    ]
  }
  template_spec = {
    containers = [
      {
        name  = var.name
        image = var.images.sunshine_desktop
        env = concat([
          {
            name = "SUNSHINE_USERNAME"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = "USERNAME"
              }
            }
          },
          {
            name = "SUNSHINE_PASSWORD"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = "PASSWORD"
              }
            }
          },
          {
            name  = "SUNSHINE_PORT"
            value = tostring(local.base_port)
          },
          {
            name  = "USER"
            value = var.user
          },
          {
            name  = "UID"
            value = tostring(var.uid)
          },
          {
            name  = "HOME"
            value = local.home_path
          },
          {
            name  = "XDG_RUNTIME_DIR"
            value = "/run/user/${var.uid}"
          },
          ], [
          for _, e in var.sunshine_extra_envs :
          {
            name  = e.name
            value = tostring(e.value)
          }
        ])
        volumeMounts = concat([
          {
            name      = "home"
            mountPath = local.home_path
          },
          {
            name      = "dev-input"
            mountPath = "/dev/input"
          },
          {
            name      = "dev-shm"
            mountPath = "/dev/shm"
          },
        ], var.sunshine_extra_volume_mounts)
        ports = concat([
          for name, port in local.tcp_ports :
          {
            containerPort = port
            protocol      = "TCP"
          }
          ], [
          for name, port in local.udp_ports :
          {
            containerPort = port
            protocol      = "UDP"
          }
        ])
        readinessProbe = {
          tcpSocket = {
            port = local.base_port
          }
        }
        livenessProbe = {
          tcpSocket = {
            port = local.base_port
          }
        }
        securityContext = var.sunshine_security_context
        resources       = var.sunshine_resources
      },
    ]
    volumes = concat([
      {
        name = "dev-input"
        hostPath = {
          path = "/dev/input"
        }
      },
      {
        name = "dev-shm"
        emptyDir = {
          medium = "Memory"
        }
      },
    ], var.sunshine_extra_volumes)
  }
}