locals {
  rclone_port                  = 8080
  minio_ca_file                = "/etc/rclone/ca-cert.pem"
  minio_client_tls_secret_name = "${var.name}-minio-client-tls"
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.release
  manifests = {
    "templates/service.yaml"    = module.service.manifest
    "templates/ingress.yaml"    = module.ingress.manifest
    "templates/deployment.yaml" = module.deployment.manifest

    # TODO: investigate better option - used only to pass in ca.crt
    "templates/minio-client-cert.yaml" = yamlencode({
      apiVersion = "cert-manager.io/v1"
      kind       = "Certificate"
      metadata = {
        name      = local.minio_client_tls_secret_name
        namespace = var.namespace
      }
      spec = {
        secretName = local.minio_client_tls_secret_name
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
          name = var.minio_ca_issuer_name
          kind = "ClusterIssuer"
        }
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
          "--read-only",
          "--dir-cache-time=4s",
          "--poll-interval=2s",
          "--ca-cert=${local.minio_ca_file}",
        ]
        env = [
          {
            name = "RCLONE_S3_ACCESS_KEY_ID"
            valueFrom = {
              secretKeyRef = {
                name = var.minio_access_secret
                key  = "AWS_ACCESS_KEY_ID"
              }
            }
          },
          {
            name = "RCLONE_S3_SECRET_ACCESS_KEY"
            valueFrom = {
              secretKeyRef = {
                name = var.minio_access_secret
                key  = "AWS_SECRET_ACCESS_KEY"
              }
            }
          },
        ]
        volumeMounts = [
          {
            name      = "minio-ca"
            mountPath = local.minio_ca_file
            subPath   = "ca.crt"
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
        name = "minio-ca"
        secret = {
          secretName = local.minio_client_tls_secret_name
        }
      },
    ]
  }
}