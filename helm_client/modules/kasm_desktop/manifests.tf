locals {
  kasm_port = 6901
  sunshine_tcp_ports = [
    47984,
    47989,
    47990,
    48010,
  ]
  sunshine_udp_ports = [
    47998,
    47999,
    48000,
    48002,
  ]
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.kasm_desktop)[1]
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
        port       = local.kasm_port
        protocol   = "TCP"
        targetPort = local.kasm_port
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
      for p in local.sunshine_tcp_ports :
      {
        name       = "sunshine-tcp-${p}"
        port       = p
        protocol   = "TCP"
        targetPort = p
      }
      ], [
      for p in local.sunshine_udp_ports :
      {
        name       = "sunshine-udp-${p}"
        port       = p
        protocol   = "UDP"
        targetPort = p
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
          service = var.name
          port    = local.kasm_port
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
        image = var.images.kasm_desktop
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
            containerPort = local.kasm_port
          },
          ], [
          for p in local.sunshine_tcp_ports :
          {
            containerPort = p
          }
          ], [
          for p in local.sunshine_udp_ports :
          {
            containerPort = p
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
          secretName = var.name
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