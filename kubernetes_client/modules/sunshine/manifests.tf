

locals {
  base_port = 47989
  base_path = "/var/sunshine"
  home_path = "${local.base_path}/mnt"
  # https://docs.lizardbyte.dev/projects/sunshine/en/latest/about/advanced_usage.html#port
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
  apps = jsonencode({
    env = {
      PATH = "$(PATH):$(HOME)/.local/bin"
    }
    apps = [
      {
        name       = "Desktop"
        image-path = "desktop.png"
      },
    ]
  })
  args = merge({
    "origin_web_ui_allowed" = "wan"
    "upnp"                  = "off"
    "cert"                  = "${local.base_path}/cacert.pem"
    "pkey"                  = "${local.base_path}/cakey.pem"
    "file_apps"             = "${local.base_path}/apps.json"
    "log_path"              = "/dev/null"
    "port"                  = tostring(local.base_port)
    }, {
    for _, arg in var.sunshine_extra_args :
    arg.name => arg.value
  })
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
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.sunshine)[1]
  manifests = {
    "templates/secret.yaml"      = module.secret.manifest
    "templates/service.yaml"     = module.service.manifest
    "templates/ingress.yaml"     = module.ingress.manifest
    "templates/statefulset.yaml" = module.statefulset.manifest
  }
}

module "secret" {
  source  = "../secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = merge({
    basename(local.args.file_apps) = local.apps
    basename(local.args.cert)      = tls_self_signed_cert.sunshine-ca.cert_pem
    basename(local.args.pkey)      = tls_private_key.sunshine-ca.private_key_pem
    }, {
    for i, config in var.sunshine_extra_configs :
    "${i}-${basename(config.path)}" => config.content
  })
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
  source             = "../ingress"
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
  source   = "../statefulset"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  template_spec = {
    # TODO: remove
    hostNetwork = true
    containers = [
      {
        name  = var.name
        image = var.images.sunshine
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          mountpoint ${local.home_path}
          sunshine --creds ${random_password.username.result} ${random_password.password.result}

          exec sunshine%{for k, v in local.args} ${k}=${v}%{endfor}
          EOF
        ]
        env = concat([
          {
            name  = "HOME"
            value = local.home_path
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
            name      = "config"
            mountPath = local.args.file_apps
            subPath   = basename(local.args.file_apps)
          },
          {
            name      = "config"
            mountPath = local.args.cert
            subPath   = basename(local.args.cert)
          },
          {
            name      = "config"
            mountPath = local.args.pkey
            subPath   = basename(local.args.pkey)
          },
          {
            name      = "home"
            mountPath = local.home_path
          },
          ], [
          for i, config in var.sunshine_extra_configs :
          {
            name      = "config"
            mountPath = config.path
            subPath   = "${i}-${basename(config.path)}"
          }
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
        name = "home"
        emptyDir = {
          medium = "Memory"
        }
      },
      {
        name = "config"
        secret = {
          secretName = module.secret.name
        }
      },
    ], var.sunshine_extra_volumes)
    dnsConfig = {
      options = [
        {
          name  = "ndots"
          value = "1"
        },
      ]
    }
  }
}