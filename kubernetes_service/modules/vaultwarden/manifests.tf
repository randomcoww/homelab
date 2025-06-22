
locals {
  vaultwarden_port = 8080
  extra_configs = merge(var.extra_configs, {
    DATA_FOLDER           = "/data"
    ROCKET_PORT           = local.vaultwarden_port
    DOMAIN                = "https://${var.service_hostname}"
    USER_ATTACHMENT_LIMIT = "0"
    ORG_ATTACHMENT_LIMIT  = "0"
  })
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.vaultwarden)[1]
  manifests = {
    "templates/deployment.yaml"    = module.deployment.manifest
    "templates/secret.yaml"        = module.secret.manifest
    "templates/service.yaml"       = module.service.manifest
    "templates/ingress.yaml"       = module.ingress.manifest
    "templates/ingress-admin.yaml" = module.ingress-admin.manifest
  }
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    for k, v in local.extra_configs :
    tostring(k) => tostring(v)
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
        name       = "vaultwarden"
        port       = local.vaultwarden_port
        protocol   = "TCP"
        targetPort = local.vaultwarden_port
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
          port    = local.vaultwarden_port
          path    = "/"
        },
      ]
    },
  ]
}

module "ingress-admin" {
  source             = "../../../modules/ingress"
  name               = "${var.name}-admin"
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
          port    = local.vaultwarden_port
          path    = "/admin"
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
  replicas = var.replicas
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  template_spec = {
    containers = [
      {
        name  = var.name
        image = var.images.vaultwarden
        env = [
          for k, v in local.extra_configs :
          {
            name = tostring(k)
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = tostring(k)
              }
            }
          }
        ]
        ports = [
          {
            containerPort = local.vaultwarden_port
          },
        ]
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.vaultwarden_port
            path   = "/alive"
          }
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.vaultwarden_port
            path   = "/alive"
          }
        }
      },
    ]
  }
}