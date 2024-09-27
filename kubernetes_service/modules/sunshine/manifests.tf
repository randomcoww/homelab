locals {
  home_path  = "/var/lib/sunshine"
  mount_path = "${local.home_path}/.config/sunshine"
  # https://docs.lizardbyte.dev/projects/sunshine/en/latest/about/advanced_usage.html#port
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
  args = merge({
    "origin_web_ui_allowed" = "wan"
    "upnp"                  = "off"
    "cert"                  = "${local.home_path}/cacert.pem"
    "pkey"                  = "${local.home_path}/cakey.pem"
    "file_apps"             = "${local.home_path}/apps.json"
    "log_path"              = "/dev/null"
    "port"                  = local.base_port
    "credentials_file"      = "${local.mount_path}/credentials.json"
    "file_state"            = "${local.mount_path}/state.json"
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
  source      = "../../../modules/metadata"
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
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = merge({
    basename(local.args.file_apps) = jsonencode({
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
    basename(local.args.cert) = tls_self_signed_cert.sunshine-ca.cert_pem
    basename(local.args.pkey) = tls_private_key.sunshine-ca.private_key_pem
    USERNAME                  = random_password.username.result
    PASSWORD                  = random_password.password.result
    }, {
    for i, config in var.sunshine_extra_configs :
    "${i}-${basename(config.path)}" => config.content
  })
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
          name = "state"
        }
        spec = {
          accessModes = [
            "ReadWriteOnce",
          ]
          resources = {
            requests = {
              storage = "1Gi"
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
        image = var.images.sunshine
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          sunshine %{for k, v in local.args} ${k}=${tostring(v)}%{endfor} --creds $USERNAME $PASSWORD
          exec sunshine%{for k, v in local.args} ${k}=${tostring(v)}%{endfor}
          EOF
        ]
        env = concat([
          {
            name  = "HOME"
            value = local.home_path
          },
          {
            name = "USERNAME"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = "USERNAME"
              }
            }
          },
          {
            name = "PASSWORD"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = "PASSWORD"
              }
            }
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
            name      = "state"
            mountPath = local.mount_path
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
        name = "config"
        secret = {
          secretName = module.secret.name
        }
      },
    ], var.sunshine_extra_volumes)
  }
}