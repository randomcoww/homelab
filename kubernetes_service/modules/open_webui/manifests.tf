locals {
  db_file = "/data/db.sqlite3"
  extra_configs = merge(var.extra_configs, {
    PORT                               = 8080
    REQUESTS_CA_BUNDLE                 = "/etc/ssl/certs/ca-certificates.crt"
    SSL_CERT_FILE                      = "/etc/ssl/certs/ca-certificates.crt" # needed for tools server TLS
    DATABASE_URL                       = "sqlite:///${local.db_file}"
    DATABASE_ENABLE_SQLITE_WAL         = true
    STORAGE_PROVIDER                   = "s3"
    S3_ADDRESSING_STYLE                = "path"
    S3_KEY_PREFIX                      = "data"
    S3_BUCKET_NAME                     = var.minio_bucket
    S3_ENDPOINT_URL                    = var.minio_endpoint
    WEBUI_SECRET_KEY                   = random_password.webui-secret-key.result
    WEB_LOADER_ENGINE                  = "safe_web"
    OAUTH_CLIENT_INFO_ENCRYPTION_KEY   = random_password.client-info-encryption-key.result
    OAUTH_SESSION_TOKEN_ENCRYPTION_KEY = random_password.session-token-encryption-key.result
    TOOL_SERVER_CONNECTIONS = jsonencode(concat(jsondecode(lookup(var.extra_configs, "TOOL_SERVER_CONNECTIONS", "[]")), [
      {
        type      = "mcp"
        url       = "https://127.0.0.1:${local.kubernetes_mcp_port}/mcp"
        auth_type = "none"
        config = {
          enable                    = true
          function_name_filter_list = ""
        }
        spec_type = "url"
        spec      = ""
        path      = ""
        key       = ""
        info = {
          id          = "kubernetes"
          name        = "kubernetes"
          description = "Query Kubernetes resources and logs"
        }
      },
    ]))
  })
  kubernetes_mcp_port      = 8081
  kubernetes_mcp_cert_path = "/etc/kubernetes-mcp-server/tls"
}

resource "random_password" "webui-secret-key" {
  length  = 64
  special = false
}

resource "random_password" "client-info-encryption-key" {
  length  = 64
  special = false
}

resource "random_password" "session-token-encryption-key" {
  length  = 64
  special = false
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.release
  manifests = merge({
    "templates/statefulset.yaml"        = module.statefulset.manifest
    "templates/secret.yaml"             = module.secret.manifest
    "templates/tls-kubernetes-mcp.yaml" = module.tls-kubernetes-mcp.manifest
    "templates/service.yaml"            = module.service.manifest
    "templates/httproute.yaml"          = module.httproute.manifest

    # kubernetes-mcp
    "templates/mcp-serviceaccount.yaml" = yamlencode({
      apiVersion = "v1"
      kind       = "ServiceAccount"
      metadata = {
        name = var.name
        labels = {
          app     = var.name
          release = var.release
        }
      }
    })
    "templates/mcp-clusterrole.yaml" = yamlencode({
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "ClusterRole"
      metadata = {
        name = var.name
        labels = {
          app     = var.name
          release = var.release
        }
      }
      rules = [
        {
          apiGroups = ["*"]
          resources = ["*"]
          verbs     = ["list", "watch", "get"]
        },
      ]
    })
    "templates/mcp-clusterrolebinding.yaml" = yamlencode({
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "ClusterRoleBinding"
      metadata = {
        name = var.name
        labels = {
          app     = var.name
          release = var.release
        }
      }
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io"
        kind     = "ClusterRole"
        name     = var.name
      }
      subjects = [
        {
          kind      = "ServiceAccount"
          name      = var.name
          namespace = var.namespace
        },
      ]
    })
    }, {
    for i, m in module.litestream-overlay.additional_manifests :
    "templates/litestream-${i}.yaml" => m
  })
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
        name       = "open-webui"
        port       = local.extra_configs.PORT
        protocol   = "TCP"
        targetPort = local.extra_configs.PORT
      },
    ]
  }
}

module "httproute" {
  source  = "../../../modules/httproute"
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    parentRefs = [
      merge({
        kind = "Gateway"
      }, var.gateway_ref),
    ]
    hostnames = [
      var.ingress_hostname,
    ]
    rules = [
      {
        matches = [
          {
            path = {
              type  = "PathPrefix"
              value = "/"
            }
          },
        ]
        backendRefs = [
          {
            name = module.service.name
            port = local.extra_configs.PORT
          },
        ]
      }
    ]
  }
}

module "litestream-overlay" {
  source = "../litestream_overlay"

  name    = var.name
  app     = var.name
  release = var.release
  images = {
    litestream = var.images.litestream
  }
  litestream_config = {
    dbs = [
      {
        path                = local.db_file
        monitor-interval    = "1s"
        checkpoint-interval = "60s"
        replica = {
          type          = "s3"
          endpoint      = var.minio_endpoint
          bucket        = var.minio_bucket
          path          = "$POD_NAME/litestream"
          sync-interval = "1s"
          part-size     = "50MB"
          concurrency   = 10
        }
      },
    ]
  }
  sqlite_path         = local.db_file
  minio_access_secret = var.minio_access_secret

  template_spec = {
    serviceAccountName = var.name
    resources = {
      requests = {
        memory = "2Gi"
      }
      limits = {
        memory = "4Gi"
      }
    }
    containers = [
      {
        name  = var.name
        image = var.images.open_webui
        env = concat([
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
          ], [
          {
            name = "S3_ACCESS_KEY_ID"
            valueFrom = {
              secretKeyRef = {
                name = var.minio_access_secret
                key  = "AWS_ACCESS_KEY_ID"
              }
            }
          },
          {
            name = "S3_SECRET_ACCESS_KEY"
            valueFrom = {
              secretKeyRef = {
                name = var.minio_access_secret
                key  = "AWS_SECRET_ACCESS_KEY"
              }
            }
          },
        ])
        ports = [
          {
            containerPort = local.extra_configs.PORT
          },
        ]
        volumeMounts = [
          {
            name      = "ca-trust-bundle"
            mountPath = local.extra_configs.REQUESTS_CA_BUNDLE
            readOnly  = true
          },
        ]
        readinessProbe = {
          httpGet = {
            port = local.extra_configs.PORT
            path = "/health/db"
          }
          timeoutSeconds = 2
        }
        livenessProbe = {
          httpGet = {
            port = local.extra_configs.PORT
            path = "/health"
          }
        }
        startupProbe = {
          httpGet = {
            port = local.extra_configs.PORT
            path = "/health"
          }
          failureThreshold = 6
        }
      },
      # kubernetes-mcp
      {
        name  = "${var.name}-kubernetes-mcp"
        image = var.images.kubernetes_mcp
        args = [
          "--port",
          tostring(local.kubernetes_mcp_port),
          "--disable-multi-cluster",
          "--stateless",
          "--cluster-provider",
          "in-cluster",
          "--tls-cert",
          "${local.kubernetes_mcp_cert_path}/tls.crt",
          "--tls-key",
          "${local.kubernetes_mcp_cert_path}/tls.key",
        ]
        volumeMounts = [
          {
            name      = "service-account"
            mountPath = "/var/run/secrets/kubernetes.io/serviceaccount"
            readOnly  = true
          },
          {
            name      = "kubernetes-mcp-cert"
            mountPath = local.kubernetes_mcp_cert_path
            readOnly  = true
          },
        ]
        livenessProbe = {
          httpGet = {
            scheme = "HTTPS"
            port   = local.kubernetes_mcp_port
            path   = "/healthz"
          }
          initialDelaySeconds = 10
          timeoutSeconds      = 2
        }
        readinessProbe = {
          httpGet = {
            scheme = "HTTPS"
            port   = local.kubernetes_mcp_port
            path   = "/healthz"
          }
        }
      },
    ]
    volumes = [
      {
        name = "${var.name}-litestream-data"
        emptyDir = {
          medium = "Memory"
        }
      },
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
      {
        name = "dev-shm"
        emptyDir = {
          medium    = "Memory"
          sizeLimit = "1Gi"
        }
      },
      {
        name = "kubernetes-mcp-cert"
        secret = {
          secretName = module.tls-kubernetes-mcp.name
        }
      },
      {
        name = "service-account"
        projected = {
          sources = [
            {
              serviceAccountToken = {
                path              = "token"
                expirationSeconds = 3600
              }
            },
            {
              downwardAPI = {
                items = [
                  {
                    path = "namespace"
                    fieldRef = {
                      fieldPath = "metadata.namespace"
                    }
                  },
                ]
              }
            },
            {
              configMap = {
                name = "kube-root-ca.crt"
                items = [
                  {
                    key  = "ca.crt"
                    path = "ca.crt"
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

module "statefulset" {
  source = "../../../modules/statefulset"

  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = var.replicas
  annotations = merge({
    "checksum/secret"             = sha256(module.secret.manifest)
    "checksum/tls-kubernetes-mcp" = sha256(module.tls-kubernetes-mcp.manifest)
    }, {
    for i, m in module.litestream-overlay.additional_manifests :
    "checksum/litestream-${i}" => sha256(m)
  })
  /* persistent path for sqlite
  spec = {
    volumeClaimTemplates = [
      {
        metadata = {
          name = "${var.name}-litestream-data"
        }
        spec = {
          accessModes = [
            "ReadWriteOnce",
          ]
          resources = {
            requests = {
              storage = "16Gi"
            }
          }
          storageClassName = "local-path"
        }
      },
    ]
  }
  */
  template_spec = module.litestream-overlay.template_spec
}