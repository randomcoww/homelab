locals {
  config_path      = "/opt/config.yml"
  registry_ui_port = 8080
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.registry_ui)[1]
  manifests = {
    "templates/deployment.yaml" = module.deployment.manifest
    "templates/secret.yaml"     = module.secret.manifest
    "templates/service.yaml"    = module.service.manifest
    "templates/ingress.yaml"    = module.ingress.manifest
  }
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    # https://github.com/Quiq/registry-ui/blob/master/config.yml
    basename(local.config_path) = yamlencode({
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
    containers = [
      {
        name  = var.name
        image = var.images.registry_ui
        args = [
          "-config-file",
          local.config_path,
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
            subPath   = basename(local.config_path)
          },
          {
            name      = "certs"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
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
        name = "config"
        secret = {
          secretName = module.secret.name
        }
      },
      {
        name = "certs"
        hostPath = {
          path = "/etc/ssl/certs/ca-certificates.crt"
          type = "File"
        }
      },
    ]
  }
}