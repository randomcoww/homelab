locals {
  tcp_port_offsets = {
    https = -5
    http  = 0
    web   = 1
    rtsp  = 21
  }
  udp_port_offsets = {
    video   = 9
    control = 10
    audio   = 11
    mic     = 13
  }
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.kasm)[1]
  manifests = {
    "templates/secret.yaml"           = module.secret.manifest
    "templates/service.yaml"          = module.service.manifest
    "templates/service-sunshine.yaml" = module.service-sunshine.manifest
    "templates/ingress.yaml"          = module.ingress.manifest
    "templates/statefulset.yaml"      = module.statefulset.manifest
  }
}

module "secret" {
  source  = "../secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    ssh_known_hosts = join("\n", var.ssh_known_hosts)
  }
}

module "service" {
  source  = "../service"
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = "kasm"
        port       = var.ports.kasm
        protocol   = "TCP"
        targetPort = var.ports.kasm
      },
    ]
  }
}

module "service-sunshine" {
  source  = "../service"
  name    = "${var.name}-sunshine"
  app     = var.name
  release = var.release
  annotations = {
    "external-dns.alpha.kubernetes.io/hostname" = var.sunshine_service_hostname
  }
  spec = {
    type = "ClusterIP"
    externalIPs = [
      var.sunshine_service_ip
    ]
    ports = concat([
      for name, offset in local.tcp_port_offsets :
      {
        name       = name
        port       = var.ports.sunshine + offset
        protocol   = "TCP"
        targetPort = var.ports.sunshine + offset
      }
      ], [
      for name, offset in local.udp_port_offsets :
      {
        name       = name
        port       = var.ports.sunshine + offset
        protocol   = "UDP"
        targetPort = var.ports.sunshine + offset
      }
    ])
  }
}

module "ingress" {
  source             = "../ingress"
  name               = var.name
  app                = var.name
  release            = var.release
  ingress_class_name = var.ingress_class_name
  annotations        = var.nginx_ingress_annotations
  rules = [
    {
      host = var.kasm_service_hostname
      paths = [
        {
          service = module.service.name
          port    = var.ports.kasm
          path    = "/"
        }
      ]
    },
  ]
}

module "statefulset" {
  source   = "../statefulset"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = 1
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  spec = {
    containers = [
      {
        name  = var.name
        image = var.images.kasm
        env = concat([
          {
            name  = "USER"
            value = var.user
          },
          {
            name  = "HOME"
            value = "/home/${var.user}"
          },
          {
            name  = "UID"
            value = tostring(var.uid)
          },
          {
            name  = "XDG_RUNTIME_DIR"
            value = "/run/user/${var.uid}"
          },
          {
            name  = "SUNSHINE_PORT"
            value = tostring(var.ports.sunshine)
          },
          ], [
          for k, v in var.extra_envs :
          {
            name  = tostring(k)
            value = tostring(v)
          }
        ])
        volumeMounts = [
          {
            name      = "desktop-home"
            mountPath = "/home/${var.user}"
          },
          {
            name      = "dshm"
            mountPath = "/dev/shm"
          },
          {
            name        = "secret"
            mountPath   = "/etc/ssh/ssh_known_hosts"
            subPathExpr = "ssh_known_hosts"
            readOnly    = true
          },
        ]
        ports = concat([
          {
            containerPort = var.ports.kasm
            protocol      = "TCP"
          },
          ], [
          for name, offset in local.tcp_port_offsets :
          {
            containerPort = var.ports.sunshine + offset
            protocol      = "TCP"
          }
          ], [
          for name, offset in local.udp_port_offsets :
          {
            containerPort = var.ports.sunshine + offset
            protocol      = "UDP"
          }
        ])
        securityContext = {
          capabilities = {
            add = [
              "AUDIT_WRITE",
            ]
          }
        }
        resources = var.resources
      },
    ]
    volumes = [
      {
        name = "dshm"
        emptyDir = {
          medium = "Memory"
        }
      },
      {
        name = "secret"
        secret = {
          secretName = module.secret.name
        }
      },
    ]
  }
  volume_claim_templates = [
    {
      metadata = {
        name = "desktop-home"
      }
      spec = {
        accessModes = var.storage_access_modes
        resources = {
          requests = {
            storage = var.volume_claim_size
          }
        }
        storageClassName = var.storage_class
      }
    },
  ]
}