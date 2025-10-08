locals {
  config_path     = "/etc/registry"
  minio_ca_file   = "/usr/local/share/ca-certificates/ca-cert.pem"
  tls_secret_name = "${var.name}-tls"
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
    "templates/cert.yaml" = yamlencode({
      apiVersion = "cert-manager.io/v1"
      kind       = "Certificate"
      metadata = {
        name      = local.tls_secret_name
        namespace = var.namespace
      }
      spec = {
        secretName = local.tls_secret_name
        isCA       = false
        privateKey = {
          algorithm = "ECDSA"
          size      = 521
        }
        commonName = var.name
        usages = [
          "key encipherment",
          "digital signature",
          "server auth",
        ]
        ipAddresses = [
          "127.0.0.1",
          var.service_ip,
        ]
        dnsNames = [
          var.name,
          "${var.name}.${var.namespace}",
        ]
        issuerRef = {
          name = var.ca_issuer_name
          kind = "ClusterIssuer"
        }
      }
    })

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
                        ${local.config_path}/config.yaml
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
                      },
                      {
                        name      = "ca-trust-bundle"
                        mountPath = "/etc/ssl/certs/ca-certificates.crt"
                        subPath   = "ca.crt"
                        readOnly  = true
                      },
                    ]
                  },
                ]
                volumes = [
                  {
                    name = "config"
                    projected = {
                      sources = [
                        {
                          secret = {
                            name = module.secret.name
                            items = [
                              {
                                key  = "config.yaml"
                                path = "config.yaml"
                              },
                            ]
                          }
                        },
                      ]
                    }
                  },
                  {
                    name = "ca-trust-bundle"
                    configMap = {
                      name = "ca-trust-bundle.crt"
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
    "config.yaml" = yamlencode({
      version = "0.1"
      http = {
        addr   = "0.0.0.0:${var.ports.registry}"
        prefix = "/"
        tls = {
          certificate = "${local.config_path}/cert.pem"
          key         = "${local.config_path}/key.pem"
          clientcas = [
            "${local.config_path}/ca-cert.pem",
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
          exec registry serve ${local.config_path}/config.yaml
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
          },
          {
            name      = "ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            subPath   = "ca.crt"
            readOnly  = true
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
        projected = {
          sources = [
            {
              secret = {
                name = local.tls_secret_name
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
            {
              secret = {
                name = module.secret.name
                items = [
                  {
                    key  = "config.yaml"
                    path = "config.yaml"
                  },
                ]
              }
            },
          ]
        }
      },
    ]
  }
}