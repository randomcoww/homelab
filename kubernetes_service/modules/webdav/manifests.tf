locals {
  rclone_port  = 8080
  ca_cert_path = "/var/tmp/rclone/trusted-ca.crt"
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.rclone)[1]
  manifests = {
    "templates/service.yaml"    = module.service.manifest
    "templates/secret.yaml"     = module.secret.manifest
    "templates/ingress.yaml"    = module.ingress.manifest
    "templates/deployment.yaml" = module.deployment.manifest
  }
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    RCLONE_S3_ACCESS_KEY_ID      = var.minio_access_key_id
    RCLONE_S3_SECRET_ACCESS_KEY  = var.minio_secret_access_key
    basename(local.ca_cert_path) = var.minio_ca_cert
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
        name       = var.name
        port       = local.rclone_port
        protocol   = "TCP"
        targetPort = local.rclone_port
      },
    ]
    sessionAffinity = "ClientIP"
    sessionAffinityConfig = {
      clientIP = {
        timeoutSeconds = 10800
      }
    }
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
          service = var.name
          port    = local.rclone_port
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
  replicas = var.replicas
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  template_spec = {
    containers = [
      {
        name  = var.name
        image = var.images.rclone
        args = [
          "serve",
          "webdav",
          "--addr=0.0.0.0:${local.rclone_port}",
          ":s3:${var.minio_bucket}",
          "--s3-provider=Minio",
          "--s3-endpoint=${var.minio_endpoint}",
          "--no-modtime",
          "--read-only",
          "--dir-cache-time=4s",
          "--poll-interval=2s",
          "--ca-cert=${local.ca_cert_path}",
        ]
        envFrom = [
          {
            secretRef = {
              name = module.secret.name
            }
          },
        ]
        volumeMounts = [
          {
            name      = "secret"
            mountPath = local.ca_cert_path
            subPath   = basename(local.ca_cert_path)
          },
        ]
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.rclone_port
            path   = "/"
          }
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.rclone_port
            path   = "/"
          }
        }
      },
    ]
    volumes = [
      {
        name = "secret"
        secret = {
          secretName = var.name
        }
      },
    ]
  }
}