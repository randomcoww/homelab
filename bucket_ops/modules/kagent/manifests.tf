locals {
  pg_tls_path       = "/var/run/kagent/pg/tls"
  redis_tls_path    = "/var/run/kagent/redis/tls"
  postgres_database = "kagent"
  postgres_username = "kagent"
  redis_port        = 6379 # not configurable
  ui_port           = 8080
  tools_port        = 8084

  values = {
    database = {
      postgres = {
        url = join("&", [
          "postgres://${local.postgres_username}:${random_password.postgres-password.result}@${var.name}-pg-rw.${var.namespace}/${local.postgres_database}?sslmode=verify-full",
          "sslrootcert=${local.pg_tls_path}/ca.crt",
          "sslcert=${local.pg_tls_path}/tls.crt",
          "sslkey=${local.pg_tls_path}/tls.key",
        ])
        vectorEnabled = true
        bundled = {
          enabled = false
        }
      }
    }
    controller = {
      replicas = 2
      auth = {
        mode = "trusted-proxy"
      }
      pdb = {
        enabled = true
      }
      metrics = {
        enabled = true
        serviceMonitor = {
          enabled = true
        }
      }
      volumeMounts = [
        {
          name      = "pg-client-tls"
          mountPath = local.pg_tls_path
        },
        {
          name      = "ca-trust-bundle"
          mountPath = "/etc/ssl/certs/ca-certificates.crt"
          subPath   = "ca.crt"
          readOnly  = true
        },
      ]
      volumes = [
        {
          name = "pg-client-tls"
          secret = {
            secretName = "${var.name}-pg-client-tls"
          }
        },
        {
          name = "ca-trust-bundle"
          configMap = {
            name = "trust-manager-ca-internal-bundle"
          }
        },
      ]
    }
    kagent-tools = {
      enabled = false # create this as an extra object to override timeout
    }
    ui = {
      externalUrl = "https://${var.ingress_hostname}"
      replicas    = 1
      service = {
        ports = {
          port       = local.ui_port
          targetPort = local.ui_port
        }
      }
      image = {
        registry   = "zot.cluster.internal"
        repository = "randomcoww/kagent-ui-patched"
        tag        = "v0.10.5.1793848851@sha256:5143833525c9aa73157791e00529149a10d99df9086fe008fbc12bf2bfc3b32d" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/kagent-ui-patched
      }
      streamTimeoutSeconds = "3600"
      nginx = {
        proxyReadTimeout = "3600s"
        proxySendTimeout = "3600s"
        proxyBuffering   = "off"
      }
      env = [
        {
          name  = "UNDICI_BODY_TIMEOUT" # custom hack in UI image picks up these values
          value = "3600000"
        },
        {
          name  = "UNDICI_HEADERS_TIMEOUT" # custom hack in UI image picks up these values
          value = "3600000"
        },
        {
          name  = "KEEP_ALIVE_TIMEOUT"
          value = "3600000"
        },
      ]
    }
    providers = {
      default = "openAI"
      openAI = {
        model           = "qwen-3-8-flash-next"
        apiKeySecretRef = module.openai-secret.name
        apiKeySecretKey = "OPENAI_API_KEY"
        config = {
          baseUrl = "https://${var.openai_endpoint}/v1"
        }
        tls = {
          caCertSecretRef = "${var.name}-pg-client-tls" # CA is same as one used for postgres access
          caCertSecretKey = "ca.crt"
        }
      }
    }
    kgateway-agent = {
      enabled = false
    }
    argo-rollouts-agent = {
      enabled = false
    }
    istio-agent = {
      enabled = false
    }
    promql-agent = {
      enabled = false
    }
    grafana-mcp = {
      enabled = false
    }
    observability-agent = {
      enabled = false
    }
    oauth2-proxy = {
      replicaCount = 1
      enabled      = true
      sessionStorage = {
        type = "redis"
        redis = {
          existingSecret = module.redis-secret.name
          passwordKey    = "redis-password"
          clientType     = "standalone"
          standalone = {
            connectionUrl = "rediss://${var.name}-redis.${var.namespace}:${local.redis_port}/0"
          }
        }
      }
      extraArgs = {
        redis-insecure-skip-tls-verify = true
        redis-ca-path                  = "${local.redis_tls_path}/ca.crt"
        scope                          = join(" ", var.oidc_scopes)
      }
      extraVolumeMounts = [
        {
          name      = "redis-tls"
          mountPath = local.redis_tls_path
        },
      ]
      extraVolumes = [
        {
          name = "redis-tls"
          secret = {
            secretName = "${var.name}-redis-tls"
          }
        },
      ]
      config = {
        existingSecret = module.oidc-secret.name
      }
      extraEnv = [
        {
          name  = "OIDC_ISSUER_URL"
          value = var.oidc_issuer_url
        },
        {
          name  = "OIDC_REDIRECT_URL"
          value = "https://${var.ingress_hostname}/oauth2/callback"
        },
        {
          name  = "UPSTREAM_URL"
          value = "http://${var.name}-ui.${var.namespace}:${local.ui_port}"
        },
      ]
      gatewayApi = {
        enabled = true
        gatewayRef = merge({
          kind = "Gateway"
        }, var.gateway_ref)
        hostnames = [
          var.ingress_hostname,
        ]
      }
    }
    extraObjects = [
    ]
  }
}

resource "random_password" "postgres-password" {
  length  = 32
  special = false
}

resource "random_password" "redis-password" {
  length  = 32
  special = false
}

resource "random_password" "storage-cookie-secret" {
  length  = 32
  special = false
}

module "oidc-secret" {
  source    = "../../../modules/secret"
  name      = "${var.name}-oidc"
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    client-id     = var.oidc_client_id
    client-secret = var.oidc_client_secret
    cookie-secret = random_password.storage-cookie-secret.result
  }
}

module "redis-secret" {
  source    = "../../../modules/secret"
  name      = "${var.name}-redis"
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    redis-password = random_password.redis-password.result
  }
}

module "postgres-secret" {
  source    = "../../../modules/secret"
  name      = "${var.name}-postgres"
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    username = local.postgres_username
    password = random_password.postgres-password.result
  }
}

module "openai-secret" {
  source    = "../../../modules/secret"
  name      = "${var.name}-openai"
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    OPENAI_API_KEY = var.openai_apikey
  }
}