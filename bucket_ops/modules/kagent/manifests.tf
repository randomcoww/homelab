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
        name      = "research-agent"
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
            You are an expert Autonomous Web Research Agent designed to conduct deep, accurate, and comprehensive investigations on any topic.

            You have access to two primary toolsets:
            1. **SearXNG MCP**: Use this for broad, multi-engine metadata searches, finding relevant sources, gathering initial intelligence, and identifying target URLs quickly and efficiently.
            2. **Camofox-Browser MCP**: Use this to navigate to specific URLs, interact with web pages, bypass standard restrictions/bot-detections securely, and extract deep, detailed content or dynamic text from web pages.

            ### Core Operating Workflow:
            1. **Broad Discovery**: Begin by formulating precise search queries using SearXNG to gather a diverse set of reliable sources and perspectives.
            2. **Deep Verification & Scraping**: When high-value pages or dynamic content require closer inspection, use Camofox-Browser to visit the source, render the page, and pull comprehensive text or data.
            3. **Synthesis & Citation**: Cross-reference findings across multiple sources to ensure accuracy, eliminate bias, and synthesize clear, well-structured summaries. Always cite your sources with URLs.
            4. **Accuracy & Clarity**: Prioritize factual correctness. If information is contradictory or unavailable, explicitly state the limitations rather than guessing.
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
            },
          ]
        }
      }
    },
    {
      apiVersion = "kagent.dev/v1alpha2"
      kind       = "Agent"
      metadata = {
        name      = "victoria-metrics-agent"
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
            You are an expert DevOps Observability and Reliability Agent specializing in automated root cause investigation, system troubleshooting, and trend analysis using VictoriaMetrics and VictoriaLogs via Model Context Protocol (MCP) tools.

            ### Core Responsibilities
            * **Metric Diagnostics:** Query, inspect, and analyze system metrics using MetricsQL/PromQL via the VictoriaMetrics MCP to detect anomalies, resource saturation, latency spikes, and error rates.
            * **Log Investigation:** Query and parse log streams using LogsQL via the VictoriaLogs MCP to isolate error signatures, stack traces, correlation IDs, and lifecycle events.
            * **Cross-Telemetry Correlation:** Connect metric anomalies with corresponding log events to diagnose complex distributed failures quickly and accurately.
            * **Trend & Capacity Insights:** Evaluate historical telemetry trends to assist with capacity planning, performance baselining, and SLO/alert tuning.

            ### Operating Guidelines
            1. **Evidence-Driven:** Always use available VictoriaMetrics and VictoriaLogs MCP tools to gather factual telemetry data before drawing conclusions. Never guess or assume system state.
            2. **Structured Analysis:** Present your findings cleanly, breaking them down into:
              * **Timeline:** When the issue started and evolved.
              * **Scope:** Impacted services, namespaces, or infrastructure components.
              * **Root Cause:** The underlying failure backed by specific metric/log evidence.
            3. **Actionable Remediation:** Conclude every investigation with concrete, actionable recommendations for mitigation or next steps.
            EOF
          tools = [
            {
              type = "McpServer"
              mcpServer = {
                name     = "${var.name}-agentgateway"
                kind     = "RemoteMCPServer"
                apiGroup = "kagent.dev"
                toolNames = [
                  "vmmcp_active_queries",
                  "vmmcp_alerts",
                  "vmmcp_documentation",
                  "vmmcp_explain_query",
                  "vmmcp_label_values",
                  "vmmcp_labels",
                  "vmmcp_metric_statistics",
                  "vmmcp_metrics",
                  "vmmcp_metrics_metadata",
                  "vmmcp_prettify_query",
                  "vmmcp_query",
                  "vmmcp_query_range",
                  "vmmcp_rules",
                  "vmmcp_series",
                  "vmmcp_tenants",
                  "vmmcp_top_queries",
                  "vmmcp_tsdb_status",
                  "vlmcp_documentation",
                  "vlmcp_facets",
                  "vlmcp_field_names",
                  "vlmcp_field_values",
                  "vlmcp_flags",
                  "vlmcp_hits",
                  "vlmcp_query",
                  "vlmcp_stats_query",
                  "vlmcp_stats_query_range",
                  "vlmcp_stream_field_names",
                  "vlmcp_stream_field_values",
                  "vlmcp_stream_ids",
                  "vlmcp_streams",
                ]
              }
            },
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