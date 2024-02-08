locals {
  config_path = "/etc/bsimp/config.toml"
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.bsimp)[1]
  manifests = {
    "templates/secret.yaml"     = module.secret.manifest
    "templates/service.yaml"    = module.service.manifest
    "templates/ingress.yaml"    = module.ingress.manifest
    "templates/deployment.yaml" = module.deployment.manifest
  }
}

module "secret" {
  source  = "../secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    "config.toml" = templatefile("${path.module}/templates/config.toml", {
      s3_endpoint          = var.s3_endpoint
      s3_resource          = var.s3_resource
      s3_access_key_id     = var.s3_access_key_id
      s3_secret_access_key = var.s3_secret_access_key
    })
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
        name       = "bsimp"
        port       = var.ports.bsimp
        protocol   = "TCP"
        targetPort = var.ports.bsimp
      },
    ]
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
      host = var.service_hostname
      paths = [
        {
          service = var.name
          port    = var.ports.bsimp
          path    = "/"
        },
      ]
    },
  ]
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
  spec = {
    containers = [
      {
        name  = var.name
        image = var.images.bsimp
        args = [
          "-config=${local.config_path}",
          "-http=:${var.ports.bsimp}",
        ]
        ports = [
          {
            containerPort = var.ports.bsimp
          },
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.config_path
            subPath   = "config.toml"
          },
        ]
      },
    ]
    volumes = [
      {
        name = "config"
        secret = {
          secretName = var.name
        }
      },
    ]
  }
}