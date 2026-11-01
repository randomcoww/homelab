locals {
  pg_tls_path       = "/var/run/kagent/pg/tls"
  redis_tls_path    = "/var/run/kagent/redis/tls"
  postgres_database = "kagent"
  postgres_username = "kagent"
  redis_port        = 6379 # not configurable
  ui_port           = 8080

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
      ]
      volumes = [
        {
          name = "pg-client-tls"
          secret = {
            secretName = "${var.name}-pg-client-tls"
          }
        },
      ]
    }
    ui = {
      externalUrl = "https://${var.ingress_hostname}"
      replicas    = 2
      service = {
        ports = {
          port       = local.ui_port
          targetPort = local.ui_port
        }
      }
    }
    providers = {
      default = "openAI"
      openAI = {
        model           = "qwen-3-8-flash-next"
        apiKeySecretRef = module.openai-secret.name
        apiKeySecretKey = "OPENAI_API_KEY"
        config = {
          baseUrl = "https://${var.agentgateway_endpoint}/v1"
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
      replicaCount = 2
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

  crs = [
    {
      apiVersion = "kagent.dev/v1alpha2"
      kind       = "RemoteMCPServer"
      metadata = {
        name      = "${var.name}-agentgateway"
        namespace = var.namespace
      }
      spec = {
        url            = "https://${var.agentgateway_endpoint}/mcp"
        protocol       = "STREAMABLE_HTTP"
        timeout        = "30s"
        sseReadTimeout = "5m0s"
        description    = "Agentgateway aggregate MCP tools"
        tls = {
          caCertSecretRef = "${var.name}-pg-client-tls" # CA is same as one used for postgres access
          caCertSecretKey = "ca.crt"
        }
      }
    },
    {
      apiVersion = "kagent.dev/v1alpha2"
      kind       = "Agent"
      metadata = {
        name      = "websearch-agent"
        namespace = var.namespace
      }
      spec = {
        type = "Declarative"
        declarative = {
          modelConfig = "default-model-config"
          promptTemplate = {
            dataSources = [
              {
                kind  = "ConfigMap"
                name  = "kagent-builtin-prompts"
                alias = "builtin"
              },
            ]
          }
          systemMessage = <<-EOF
            You are a pragmatic senior engineer.
            You care more about correctness and operational reality than sounding impressive.

            ## Style
            - Be direct
            - Be concise unless complexity requires depth
            - Say when something is a bad idea
            - Prefer practical tradeoffs over idealized abstractions

            ## Avoid
            - Sycophancy
            - Hype language
            - Overexplaining obvious things
            EOF
          tools = [
            {
              type = "McpServer"
              mcpServer = {
                name     = "${var.name}-agentgateway"
                kind     = "RemoteMCPServer"
                apiGroup = "kagent.dev"
                toolNames = [
                  "searxng_searxng_instance_info",
                  "searxng_searxng_search_suggestions",
                  "searxng_searxng_web_search",
                  "camofox_camofox_close_session",
                  "camofox_camofox_evaluate_js",
                  "camofox_camofox_get_page_html",
                  "camofox_camofox_scroll_element",
                  "camofox_camofox_scroll_element_and_snapshot",
                  "camofox_camofox_wait_for",
                  "camofox_camofox_wait_for_selector",
                  "camofox_camofox_wait_for_text",
                  "camofox_click",
                  "camofox_close_tab",
                  "camofox_create_tab",
                  "camofox_extract_resources",
                  "camofox_extract_structured",
                  "camofox_list_tabs",
                  "camofox_navigate",
                  "camofox_navigate_and_snapshot",
                  "camofox_resolve_blobs",
                  "camofox_scroll",
                  "camofox_scroll_and_snapshot",
                  "camofox_snapshot",
                  "camofox_youtube_transcript",
                ]
              }
            }
          ]
        }
      }
    },
  ]
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