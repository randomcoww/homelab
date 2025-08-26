locals {
  config_path     = "/etc/registry/config.yml"
  trusted_ca_path = "/usr/local/share/ca-certificates/ca-cert.pem"
  ca_cert_path    = "/etc/registry/ca-cert.pem"
  cert_path       = "/etc/registry/cert.pem"
  key_path        = "/etc/registry/key.pem"
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.registry)[1]
  manifests = {
    "templates/deployment.yaml" = module.deployment.manifest
    "templates/secret.yaml"     = module.secret.manifest
    "templates/service.yaml"    = module.service.manifest
  }
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    # use the same CA as other internal resources like minio
    basename(local.trusted_ca_path) = var.ca.cert_pem
    basename(local.ca_cert_path)    = var.ca.cert_pem
    basename(local.cert_path)       = tls_locally_signed_cert.registry.cert_pem
    basename(local.key_path)        = tls_private_key.registry.private_key_pem
    basename(local.config_path) = yamlencode({
      version = "0.1"
      http = {
        addr   = "0.0.0.0:${var.ports.registry}"
        prefix = "/"
        tls = {
          certificate = local.cert_path
          key         = local.key_path
          clientcas = [
            local.ca_cert_path,
          ]
          clientauth = "verify-client-cert-if-given"
          minimumtls = "tls1.3"
        }
      }
      storage = {
        delete = {
          enabled = true
        }
        s3 = {
          accesskey      = var.s3_access_key_id
          secretkey      = var.s3_secret_access_key
          regionendpoint = var.s3_endpoint
          forcepathstyle = true
          bucket         = var.s3_bucket
          encrypt        = false
          secure         = true
          rootdirectory  = var.s3_bucket_prefix
        }
      }
      proxy = {
        remoteurl = var.proxy_remoteurl
        ttl       = var.proxy_ttl
      }
      health = {
        storagedriver = {
          enabled = true
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
    type      = "ClusterIP"
    clusterIP = var.cluster_service_ip
    ports = [
      {
        name       = "registry"
        port       = var.ports.registry
        protocol   = "TCP"
        targetPort = var.ports.registry
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
        image = var.images.registry
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          update-ca-certificates
          exec registry serve ${local.config_path}
          EOF
        ]
        ports = [
          {
            containerPort = var.ports.registry
          },
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.config_path
            subPath   = basename(local.config_path)
          },
          {
            name      = "config"
            mountPath = local.trusted_ca_path
            subPath   = basename(local.trusted_ca_path)
          },
          {
            name      = "config"
            mountPath = local.ca_cert_path
            subPath   = basename(local.ca_cert_path)
          },
          {
            name      = "config"
            mountPath = local.cert_path
            subPath   = basename(local.cert_path)
          },
          {
            name      = "config"
            mountPath = local.key_path
            subPath   = basename(local.key_path)
          },
        ]
        readinessProbe = {
          httpGet = {
            port   = var.ports.registry
            path   = "/"
            scheme = "HTTPS"
          }
        }
        livenessProbe = {
          httpGet = {
            port   = var.ports.registry
            path   = "/"
            scheme = "HTTPS"
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