locals {
  config_path = "/config"
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.wireproxy)[1]
  manifests = {
    "templates/service.yaml"    = module.service.manifest
    "templates/secret.yaml"     = module.secret.manifest
    "templates/deployment.yaml" = module.deployment.manifest
  }
}

module "secret" {
  source  = "../secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    basename(local.config_path) = <<-EOF
    ${var.wireguard_config}

    [Socks5]
    BindAddress = 0.0.0.0:${var.ports.socks5}
    EOF
  }
}

module "service" {
  source  = "../service"
  name    = var.name
  app     = var.name
  release = var.release
  annotations = {
    "external-dns.alpha.kubernetes.io/hostname" = var.service_hostname
  }
  spec = {
    type = "LoadBalancer"
    externalIPs = [
      var.service_ip,
    ]
    ports = [
      {
        name       = "socks5"
        port       = var.ports.socks5
        protocol   = "TCP"
        targetPort = var.ports.socks5
      },
    ]
  }
}

module "deployment" {
  source   = "../deployment"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = 1
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  template_spec = {
    containers = [
      {
        name  = var.name
        image = var.images.wireproxy
        args = [
          "-c",
          local.config_path,
        ]
        securityContext = {
          privileged = true
        }
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.config_path
            subPath   = basename(local.config_path)
          },
        ]
        ports = [
          {
            containerPort = var.ports.socks5
          },
        ]
        readinessProbe = {
          tcpSocket = {
            port = var.ports.socks5
          }
        }
        livenessProbe = {
          tcpSocket = {
            port = var.ports.socks5
          }
        }
      },
    ]
    volumes = [
      {
        name = "config"
        secret = {
          secretName = module.secret.name
        }
      },
    ]
  }
}