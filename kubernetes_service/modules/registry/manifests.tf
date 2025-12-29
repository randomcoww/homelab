locals {
  config_path = "/etc/registry"
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
    "templates/tls.yaml"        = module.tls.manifest
    "templates/service.yaml"    = module.service.manifest
    "templates/cronjob.yaml" = yamlencode({
      apiVersion = "batch/v1"
      kind       = "CronJob"
      metadata = {
        name = "${var.name}-garbage-collect"
        labels = {
          app     = var.name
          release = var.release
        }
      }
      spec = {
        schedule          = "0 * * * *"
        suspend           = false
        concurrencyPolicy = "Forbid"
        jobTemplate = {
          spec = {
            ttlSecondsAfterFinished = 1800
            template = {
              metadata = {
                labels = {
                  app = var.name
                }
              }
              spec = {
                restartPolicy = "Never"
                containers = [
                  {
                    name  = var.name
                    image = var.images.registry
                    args = [
                      "garbage-collect",
                      "--delete-untagged",
                      "${local.config_path}/config.yaml",
                    ]
                    env = [
                      {
                        name = "REGISTRY_STORAGE_S3_ACCESSKEY"
                        valueFrom = {
                          secretKeyRef = {
                            name = var.minio_access_secret
                            key  = "AWS_ACCESS_KEY_ID"
                          }
                        }
                      },
                      {
                        name = "REGISTRY_STORAGE_S3_SECRETKEY"
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
                        name      = "config"
                        mountPath = "${local.config_path}/config.yaml"
                        subPath   = "registry-config"
                      },
                      {
                        name      = "ca-trust-bundle"
                        mountPath = "/etc/ssl/certs/ca-certificates.crt"
                        readOnly  = true
                      },
                    ]
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
                dnsConfig = {
                  options = [
                    {
                      name  = "ndots"
                      value = "2"
                    },
                  ]
                }
              }
            }
          }
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
    registry-config = yamlencode({
      version = "0.1"
      http = {
        addr   = "0.0.0.0:${var.ports.registry}"
        prefix = "/"
        tls = {
          certificate = "${local.config_path}/tls/cert.pem"
          key         = "${local.config_path}/tls/key.pem"
          clientcas = [
            "${local.config_path}/tls/ca-cert.pem",
          ]
          clientauth = "verify-client-cert-if-given"
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
          regionendpoint              = var.minio_endpoint
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
    })
  }
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
    type              = "LoadBalancer"
    loadBalancerIP    = var.service_ip
    loadBalancerClass = var.loadbalancer_class_name
    ports = [
      {
        name       = var.name
        port       = var.ports.registry
        protocol   = "TCP"
        targetPort = var.ports.registry
      },
    ]
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
    "checksum/tls"    = sha256(module.tls.manifest)
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
        memory = "64Mi"
      }
      limits = {
        memory = "64Mi"
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
                name = var.minio_access_secret
                key  = "AWS_ACCESS_KEY_ID"
              }
            }
          },
          {
            name = "REGISTRY_STORAGE_S3_SECRETKEY"
            valueFrom = {
              secretKeyRef = {
                name = var.minio_access_secret
                key  = "AWS_SECRET_ACCESS_KEY"
              }
            }
          },
        ]
        ports = [
          {
            containerPort = var.ports.registry
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
            port   = var.ports.registry
            path   = "/"
            scheme = "HTTPS"
          }
          timeoutSeconds = 4
        }
        readinessProbe = {
          httpGet = {
            port   = var.ports.registry
            path   = "/"
            scheme = "HTTPS"
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
                name = module.tls.name
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