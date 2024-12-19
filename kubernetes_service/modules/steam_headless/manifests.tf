locals {
  home_path = "/home/default"
  # https://docs.lizardbyte.dev/projects/sunshine/en/latest/about/advanced_usage.html#port
  base_port = 47989
  tcp_ports = {
    https = local.base_port - 5
    http  = local.base_port
    web   = local.base_port + 1
    rtsp  = local.base_port + 21
    novnc = 8083
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
  app_version = split(":", var.images.steam)[1]
  manifests = {
    "templates/secret.yaml"           = module.secret.manifest
    "templates/service.yaml"          = module.service.manifest
    "templates/ingress-sunshine.yaml" = module.ingress-sunshine.manifest
    "templates/ingress-vnc.yaml"      = module.ingress-vnc.manifest
    "templates/statefulset.yaml"      = module.statefulset.manifest
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
    "external-dns.alpha.kubernetes.io/hostname" = var.sunshine_hostname
  }
  spec = {
    type              = "LoadBalancer"
    loadBalancerIP    = var.sunshine_ip
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

module "ingress-sunshine" {
  source             = "../../../modules/ingress"
  name               = "${var.name}-sunshine"
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
      host = var.sunshine_admin_hostname
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

module "ingress-vnc" {
  source             = "../../../modules/ingress"
  name               = "${var.name}-vnc"
  app                = var.name
  release            = var.release
  ingress_class_name = var.ingress_class_name
  annotations        = var.nginx_ingress_annotations
  rules = [
    {
      host = var.vnc_hostname
      paths = [
        {
          service = module.service.name
          port    = local.tcp_ports.novnc
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
        image = var.images.steam
        env = concat([
          {
            name  = "NAME"
            value = var.name
          },
          {
            name  = "USER_LOCALES"
            value = "en_US.UTF-8 UTF-8"
          },
          {
            name  = "DISPLAY"
            value = ":55"
          },
          {
            name  = "SHM_SIZE"
            value = "8G"
          },
          {
            name  = "UMASK"
            value = "000"
          },
          {
            name  = "USER_PASSWORD"
            value = "password"
          },
          {
            name  = "MODE"
            value = "primary"
          },
          {
            name  = "WEB_UI_MODE"
            value = "vnc"
          },
          {
            name  = "ENABLE_VNC_AUDIO"
            value = "false"
          },
          {
            name  = "PORT_NOVNC_WEB"
            value = tostring(local.tcp_ports.novnc)
          },
          {
            name  = "NEKO_NAT1TO1"
            value = ""
          },
          {
            name  = "ENABLE_EVDEV_INPUTS"
            value = "true"
          },
          {
            name  = "ENABLE_SUNSHINE"
            value = "true"
          },
          {
            name = "SUNSHINE_USER"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = "USERNAME"
              }
            }
          },
          {
            name = "SUNSHINE_PASS"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = "PASSWORD"
              }
            }
          },
          ], [
          for _, e in var.steam_extra_envs :
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
            name             = "dev-input"
            mountPath        = "/dev/input"
            mountPropagation = "HostToContainer"
          },
          {
            name      = "dev-shm"
            mountPath = "/dev/shm"
          },
        ], var.steam_extra_volume_mounts)
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
        securityContext = var.steam_security_context
        resources       = var.steam_resources
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
    ], var.steam_extra_volumes)
  }
}