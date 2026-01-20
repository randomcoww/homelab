
locals {
  oauth2_config_path = "/etc/oauth2-proxy.cfg"
  oauth2_port        = 9090
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
  }
}

resource "random_password" "cookie-secret" {
  length           = 32
  override_special = "-_"
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    basename(local.oauth2_config_path) = <<-EOF
    session_store_type = "cookie"
    cookie_secret = "${random_password.cookie-secret.result}"

    http_address = "0.0.0.0:${local.oauth2_port}"
    reverse_proxy = true

    client_id = "${var.client_id}"
    client_secret = "${var.client_secret}"
    EOF
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
        name       = "proxy"
        port       = local.oauth2_port
        protocol   = "TCP"
        targetPort = local.oauth2_port
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
      host = var.ingress_hostname
      paths = [
        {
          service = module.service.name
          port    = local.oauth2_port
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
  replicas = 1
  affinity = var.affinity
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  template_spec = {
    resources = {
      requests = {
        memory = "64Mi"
      }
      limits = {
        memory = "64Mi"
      }
    }
    containers = [
      {
        name  = var.name
        image = var.images.oauth2_proxy
        args = concat([
          "--config",
          local.oauth2_config_path,
        ], var.extra_args)
        ports = [
          {
            containerPort = local.oauth2_port
          },
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.oauth2_config_path
            subPath   = basename(local.oauth2_config_path)
          },
          {
            name      = "ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            readOnly  = true
          },
        ]
        # TODO: add health checks
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
        name = "ca-trust-bundle"
        hostPath = {
          path = "/etc/ssl/certs/ca-certificates.crt"
          type = "File"
        }
      },
    ]
  }
}