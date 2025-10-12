locals {
  config_path     = "/etc/registry"
  minio_ca_file   = "/usr/local/share/ca-certificates/ca-cert.pem"
  tls_secret_name = "${var.name}-tls"
  ui_port         = 8080
}

resource "random_password" "event-listener-token" {
  length  = 60
  special = false
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
                        subPath   = "ca.crt"
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
                    configMap = {
                      name = var.ca_bundle_configmap
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
            url      = "http://127.0.0.1:${local.ui_port}/event-receiver"
            headers = {
              Authorization = [
                "Bearer ${random_password.event-listener-token.result}",
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
    ui-config = yamlencode({
      listen_addr   = "0.0.0.0:${local.ui_port}"
      uri_base_path = "/"
      performance = {
        catalog_page_size           = 100
        catalog_refresh_interval    = 10
        tags_count_refresh_interval = 60
      }
      registry = {
        hostname = "${var.name}.${var.namespace}:${var.ports.registry}"
        insecure = false
        username = "none"
        password = "none"
      }
      access_control = {
        anyone_can_view_events = true
        anyone_can_delete_tags = true
      }
      event_listener = {
        bearer_token      = random_password.event-listener-token.result
        retention_days    = 1
        database_driver   = "sqlite3"
        database_location = "data/registry_events.db"
        deletion_enabled  = true
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
        name       = var.name
        port       = var.ports.registry
        protocol   = "TCP"
        targetPort = var.ports.registry
      },
      {
        name       = "${var.name}-ui"
        port       = local.ui_port
        protocol   = "TCP"
        targetPort = local.ui_port
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
          port    = local.ui_port
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
    hostAliases = [
      {
        ip = "127.0.0.1"
        hostnames = [
          "${var.name}.${var.namespace}",
        ]
      },
    ]
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
      {
        name  = "${var.name}-ui"
        image = var.images.registry_ui
        args = [
          "-config-file",
          "${local.config_path}/config.yaml",
        ]
        ports = [
          {
            containerPort = local.ui_port
          },
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = "${local.config_path}/config.yaml"
            subPath   = "ui-config"
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
            port   = local.ui_port
            path   = "/"
            scheme = "HTTP"
          }
        }
        livenessProbe = {
          httpGet = {
            port   = local.ui_port
            path   = "/"
            scheme = "HTTP"
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
        name = "registry-tls"
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
          ]
        }
      },
      {
        name = "ca-trust-bundle"
        configMap = {
          name = var.ca_bundle_configmap
        }
      },
    ]
  }
}