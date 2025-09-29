locals {
  config_path     = "/var/lib/registry/config.yml"
  trusted_ca_path = "/usr/local/share/ca-certificates/ca-cert.pem"
  ca_cert_path    = "/var/lib/registry/ca-cert.pem"
  cert_path       = "/var/lib/registry/cert.pem"
  key_path        = "/var/lib/registry/key.pem"
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
            ttlSecondsAfterFinished = 300
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
                    command = [
                      "sh",
                      "-c",
                      <<-EOF
                      set -e

                      update-ca-certificates
                      exec registry garbage-collect \
                        --delete-untagged \
                        ${local.config_path}
                      EOF
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
                        mountPath = local.config_path
                        subPath   = basename(local.config_path)
                      },
                      {
                        name      = "minio-access-secret"
                        mountPath = local.trusted_ca_path
                        subPath   = "AWS_CA_BUNDLE"
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
                    name = "minio-access-secret"
                    secret = {
                      secretName = var.minio_access_secret
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
          rootdirectory               = "/${join("/", compact(split("/", "${var.minio_bucket_prefix}/${var.name}.${var.namespace}")))}"
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
        endpoints = [
          {
            disabled = false
            name     = "registry-ui"
            url      = var.event_listener_url
            headers = {
              Authorization = [
                "Bearer ${var.event_listener_token}",
              ]
            }
            timeout   = "1s"
            threshold = 5
            backoff   = "10s"
            ignoredmediatypes = [
              "application/octet-stream",
            ]
          },
        ]
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
    type              = "LoadBalancer"
    loadBalancerIP    = var.service_ip
    loadBalancerClass = var.loadbalancer_class_name
    ports = [
      {
        name       = "${var.name}-${var.namespace}"
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
  }
  template_spec = {
    containers = [
      {
        name  = "${var.name}-${var.namespace}"
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
            mountPath = local.config_path
            subPath   = basename(local.config_path)
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
          {
            name      = "minio-access-secret"
            mountPath = local.trusted_ca_path
            subPath   = "AWS_CA_BUNDLE"
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
      {
        name = "minio-access-secret"
        secret = {
          secretName = var.minio_access_secret
        }
      },
    ]
  }
}