locals {
  config_path  = "/etc/registry"
  metrics_port = 9100
}

module "secret" {
  source    = "../../../modules/secret"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    registry-config = yamlencode({
      version = "0.1"
      tags = {
        maxtags = 10000 # renovate compatibility
      }
      http = {
        addr   = "0.0.0.0:${var.service_port}"
        prefix = "/"
        tls = {
          certificate = "${local.config_path}/tls/cert.pem"
          key         = "${local.config_path}/tls/key.pem"
          clientcas = [
            "${local.config_path}/tls/ca-cert.pem",
          ]
          clientauth = "require-and-verify-client-cert"
        }
        debug = {
          addr = "0.0.0.0:${local.metrics_port}"
          prometheus = {
            enabled = true
          }
        }
      }
      log = {
        level = "info"
      }
      storage = {
        delete = {
          enabled = true
        }
        s3 = {
          regionendpoint              = "https://${var.minio_endpoint}"
          forcepathstyle              = true
          bucket                      = var.minio_bucket
          encrypt                     = false
          secure                      = true
          chunksize                   = 50 * 1024 * 1024
          multipartcopymaxconcurrency = 10
          rootdirectory               = "/${join("/", compact(split("/", "${var.minio_bucket_prefix}/${var.service_hostname}")))}"
        }
      }
      health = {
        storagedriver = {
          enabled = true
        }
      }
      notifications = {
        events = {
          includereferences = true
        }
      }
    })
  }
}

module "deployment" {
  source    = "../../../modules/deployment"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  affinity  = var.affinity
  replicas  = var.replicas
  annotations = {
    "checksum/secret"                     = sha256(module.secret.manifest)
    "checksum/minio-user-secret"          = sha256(module.minio-user-secret.manifest)
    "secret.reloader.stakater.com/reload" = "${var.name}-tls"
  }
  template_spec = {
    priorityClassName = "system-cluster-critical"
    hostAliases = [
      {
        ip = "127.0.0.1"
        hostnames = [
          var.service_hostname,
        ]
      },
    ]
    resources = {
      requests = {
        memory = "1Gi"
      }
      limits = {
        memory = "1Gi"
      }
    }
    containers = [
      {
        name  = var.name
        image = var.images.registry
        args = [
          "serve",
          "${local.config_path}/config.yaml",
        ]
        env = [
          {
            # https://github.com/distribution/distribution/issues/4270
            name  = "OTEL_TRACES_EXPORTER"
            value = "none"
          },
          {
            name = "REGISTRY_STORAGE_S3_ACCESSKEY"
            valueFrom = {
              secretKeyRef = {
                name = module.minio-user-secret.name
                key  = "AWS_ACCESS_KEY_ID"
              }
            }
          },
          {
            name = "REGISTRY_STORAGE_S3_SECRETKEY"
            valueFrom = {
              secretKeyRef = {
                name = module.minio-user-secret.name
                key  = "AWS_SECRET_ACCESS_KEY"
              }
            }
          },
        ]
        ports = [
          {
            containerPort = var.service_port
          },
          {
            containerPort = local.metrics_port
          },
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = "${local.config_path}/config.yaml"
            subPath   = "registry-config"
          },
          {
            name      = "registry-tls"
            mountPath = "${local.config_path}/tls"
          },
          {
            name      = "ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            readOnly  = true
          },
        ]
        livenessProbe = {
          httpGet = {
            port   = local.metrics_port
            path   = "/debug/health"
            scheme = "HTTP"
          }
          timeoutSeconds = 4
        }
        readinessProbe = {
          httpGet = {
            port   = local.metrics_port
            path   = "/debug/health"
            scheme = "HTTP"
          }
          timeoutSeconds = 4
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
        name = "registry-tls"
        projected = {
          sources = [
            {
              secret = {
                name = "${var.name}-tls"
                items = [
                  {
                    key  = "ca.crt"
                    path = "ca-cert.pem"
                  },
                  {
                    key  = "tls.crt"
                    path = "cert.pem"
                  },
                  {
                    key  = "tls.key"
                    path = "key.pem"
                  },
                ]
              }
            },
          ]
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

module "service" {
  source    = "../../../modules/service"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  annotations = {
    "external-dns.alpha.kubernetes.io/hostname" = var.service_hostname
    "lbipam.cilium.io/ips"                      = var.service_ip
  }
  spec = {
    type = "LoadBalancer"
    ports = [
      {
        name       = var.name
        port       = var.service_port
        protocol   = "TCP"
        targetPort = var.service_port
      },
      {
        name       = "${var.name}-metrics"
        port       = local.metrics_port
        protocol   = "TCP"
        targetPort = local.metrics_port
      },
    ]
  }
}

module "minio-user-secret" {
  source    = "../../../modules/secret"
  name      = "${var.name}-minio-user-secret"
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = merge({
    AWS_ACCESS_KEY_ID     = var.minio_user.id
    AWS_SECRET_ACCESS_KEY = var.minio_user.secret
  })
}