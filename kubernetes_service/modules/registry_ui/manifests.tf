locals {
  config_path                     = "/etc/registry-ui"
  registry_ca_path                = "/usr/local/share/ca-certificates"
  registry_client_tls_secret_name = "${var.name}-registry-client-tls"
  registry_ui_port                = 8080
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.release
  manifests = {
    "templates/deployment.yaml" = module.deployment.manifest
    "templates/secret.yaml"     = module.secret.manifest
    "templates/service.yaml"    = module.service.manifest
    "templates/ingress.yaml"    = module.ingress.manifest

    # TODO: investigate better option - used only to pass in ca.crt
    "templates/registry-client-cert.yaml" = yamlencode({
      apiVersion = "cert-manager.io/v1"
      kind       = "Certificate"
      metadata = {
        name      = local.registry_client_tls_secret_name
        namespace = var.namespace
      }
      spec = {
        secretName = local.registry_client_tls_secret_name
        isCA       = false
        privateKey = {
          algorithm = "ECDSA"
          size      = 521
        }
        commonName = var.name
        usages = [
          "key encipherment",
          "digital signature",
          "client auth",
        ]
        issuerRef = {
          name = var.registry_ca_issuer_name
          kind = "ClusterIssuer"
        }
      }
    })
  }
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    # basename(local.trusted_ca_path) = var.registry_ca_cert
    # https://github.com/Quiq/registry-ui/blob/master/config.yml
    "config.yml" = yamlencode({
      listen_addr   = "0.0.0.0:${local.registry_ui_port}"
      uri_base_path = "/"
      performance = {
        catalog_page_size           = 100
        catalog_refresh_interval    = 10
        tags_count_refresh_interval = 60
      }
      registry = {
        hostname = var.registry_url
        insecure = false
        username = "none"
        password = "none"
      }
      access_control = {
        anyone_can_view_events = true
        anyone_can_delete_tags = true
      }
      event_listener = {
        bearer_token      = var.event_listener_token
        retention_days    = 1
        database_driver   = "sqlite3"
        database_location = "data/registry_events.db"
        deletion_enabled  = true
      }
    })
  }
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
        name       = "http"
        port       = local.registry_ui_port
        protocol   = "TCP"
        targetPort = local.registry_ui_port
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
  annotations        = var.nginx_ingress_annotations
  rules = [
    {
      host = var.service_hostname
      paths = [
        {
          service = module.service.name
          port    = local.registry_ui_port
          path    = "/"
        },
      ]
    },
  ]
}

module "deployment" {
  source   = "../../../modules/deployment"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = 1
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  template_spec = {
    initContainers = [
      {
        name  = "${var.name}-certs"
        image = var.images.registry_ui
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e
          update-ca-certificates
          cp /etc/ssl/certs/ca-certificates.crt /tmp/ca-bundle/
          EOF
        ]
        volumeMounts = [
          {
            name      = "registry-ca"
            mountPath = local.registry_ca_path
          },
          {
            name      = "ca-bundle"
            mountPath = "/tmp/ca-bundle"
          },
        ]
        securityContext = {
          runAsUser = 0
        }
      },
    ]
    containers = [
      {
        name  = var.name
        image = var.images.registry_ui
        args = [
          "-config-file",
          "${local.config_path}/config.yml",
        ]
        ports = [
          {
            containerPort = local.registry_ui_port
          },
        ]
        env = [
          {
            name  = "TZ"
            value = var.timezone
          },
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.config_path
          },
          {
            name      = "ca-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            subPath   = "ca-certificates.crt"
            readOnly  = true
          },
        ]
        readinessProbe = {
          httpGet = {
            port   = local.registry_ui_port
            path   = "/"
            scheme = "HTTP"
          }
        }
        livenessProbe = {
          httpGet = {
            port   = local.registry_ui_port
            path   = "/"
            scheme = "HTTP"
          }
        }
      },
    ]
    volumes = [
      {
        name = "registry-ca"
        projected = {
          sources = [
            {
              secret = {
                name = local.registry_client_tls_secret_name
                items = [
                  {
                    key  = "ca.crt"
                    path = "ca-cert.pem"
                  },
                ]
              }
            },
          ]
        }
      },
      {
        name = "config"
        projected = {
          sources = [
            {
              secret = {
                name = module.secret.name
                items = [
                  {
                    key  = "config.yml"
                    path = "config.yml"
                  },
                ]
              }
            },
          ]
        }
      },
      {
        name = "ca-bundle"
        emptyDir = {
          medium = "Memory"
        }
      }
    ]
  }
}