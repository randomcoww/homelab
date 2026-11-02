resource "minio_s3_object" "fluxcd-kagent-crs" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "v1"
          kind       = "Secret"
          metadata = {
            name      = "${local.kagent_name}-github-mcp"
            namespace = local.kagent_namespace
          }
          type = "Opaque"
          stringData = {
            token = var.github_mcp_token
          }
        },
        {
          apiVersion = "v1"
          kind       = "Secret"
          metadata = {
            name      = "${local.kagent_name}-hindsight-mcp"
            namespace = local.kagent_namespace
          }
          type = "Opaque"
          stringData = {
            token = random_password.hindsight-api-key.result
          }
        },
        {
          apiVersion = "cert-manager.io/v1"
          kind       = "Certificate"
          metadata = {
            name      = "${local.kagent_name}-mcp-client-tls"
            namespace = local.kagent_namespace
          }
          spec = {
            secretName = "${local.kagent_name}-mcp-client-tls"
            isCA       = false
            privateKey = {
              algorithm = "ECDSA"
              size      = 521
            }
            commonName = local.kagent_name
            usages = [
              "client auth",
            ]
            issuerRef = {
              name = local.cert_issuers.ca_internal
              kind = "ClusterIssuer"
            }
          }
        },

        ## MCP servers
        {
          apiVersion = "kagent.dev/v1alpha1"
          kind       = "MCPServer"
          metadata = {
            name      = "${local.kagent_name}-alpaca"
            namespace = local.kagent_namespace
          }
          spec = {
            deployment = {
              args = [
                "alpaca-mcp-server",
              ]
              cmd  = "uvx"
              port = 3000
              env = {
                ALPACA_TOOLSETS = join(",", sort([
                  "account",
                  "trading",
                  "watchlists",
                  "assets",
                  "stock-data",
                  "crypto-data",
                  "options-data",
                  "corporate-actions",
                  "news",
                  "fixed-income-data",
                  "index-data",
                ]))
                ALPACA_PAPER_TRADE = "true"
                ALPACA_API_KEY     = var.alpaca_api_key
                ALPACA_SECRET_KEY  = var.alpaca_secret_key
              }
            }
            stdioTransport = {}
            transportType  = "stdio"
          }
        },
        {
          apiVersion = "kagent.dev/v1alpha2"
          kind       = "RemoteMCPServer"
          metadata = {
            name      = "${local.kagent_name}-github"
            namespace = local.kagent_namespace
          }
          spec = {
            url            = "https://api.githubcopilot.com/mcp"
            protocol       = "STREAMABLE_HTTP"
            timeout        = "30s"
            sseReadTimeout = "5m0s"
            description    = "GitHub MCP"
            headersFrom = [
              {
                name = "Authorization"
                valueFrom = {
                  type = "Secret"
                  name = "${local.kagent_name}-github-mcp"
                  key  = "token"
                }
              },
            ]
          }
        },
        {
          apiVersion = "kagent.dev/v1alpha2"
          kind       = "RemoteMCPServer"
          metadata = {
            name      = "${local.kagent_name}-agentgateway"
            namespace = local.kagent_namespace
          }
          spec = {
            url            = "https://${local.endpoints.agentgateway.hostname}/mcp"
            protocol       = "STREAMABLE_HTTP"
            timeout        = "30s"
            sseReadTimeout = "5m0s"
            description    = "Agentgateway aggregate MCP"
            tls = {
              caCertSecretRef = "${local.kagent_name}-mcp-client-tls"
              caCertSecretKey = "ca.crt"
            }
          }
        },
        {
          apiVersion = "kagent.dev/v1alpha2"
          kind       = "RemoteMCPServer"
          metadata = {
            name      = "${local.kagent_name}-hindsight"
            namespace = local.kagent_namespace
          }
          spec = {
            url            = "https://${local.endpoints.hindsight.hostname}/mcp"
            protocol       = "STREAMABLE_HTTP"
            timeout        = "30s"
            sseReadTimeout = "5m0s"
            description    = "Hindsight MCP"
            headersFrom = [
              {
                name = "Authorization"
                valueFrom = {
                  type = "Secret"
                  name = "${local.kagent_name}-hindsight-mcp"
                  key  = "token"
                }
              },
              {
                name  = "X-Bank-Id"
                value = local.kagent_name
              },
            ]
          }
        },

        ## Agents
        {
          apiVersion = "kagent.dev/v1alpha2"
          kind       = "Agent"
          metadata = {
            name      = "research-agent"
            namespace = local.kagent_namespace
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
                    name     = "${local.kagent_name}-agentgateway"
                    kind     = "RemoteMCPServer"
                    apiGroup = "kagent.dev"
                    toolNames = [
                      "searxng-mcp_searxng_instance_info",
                      "searxng-mcp_searxng_search_suggestions",
                      "searxng-mcp_searxng_web_search",
                      "camofox-mcp_camofox_close_session",
                      "camofox-mcp_camofox_evaluate_js",
                      "camofox-mcp_camofox_get_page_html",
                      "camofox-mcp_camofox_scroll_element",
                      "camofox-mcp_camofox_scroll_element_and_snapshot",
                      "camofox-mcp_camofox_wait_for",
                      "camofox-mcp_camofox_wait_for_selector",
                      "camofox-mcp_camofox_wait_for_text",
                      "camofox-mcp_click",
                      "camofox-mcp_close_tab",
                      "camofox-mcp_create_tab",
                      "camofox-mcp_extract_resources",
                      "camofox-mcp_extract_structured",
                      "camofox-mcp_list_tabs",
                      "camofox-mcp_navigate",
                      "camofox-mcp_navigate_and_snapshot",
                      "camofox-mcp_resolve_blobs",
                      "camofox-mcp_scroll",
                      "camofox-mcp_scroll_and_snapshot",
                      "camofox-mcp_snapshot",
                      "camofox-mcp_youtube_transcript",
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
            namespace = local.kagent_namespace
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
                    name     = "${local.kagent_name}-agentgateway"
                    kind     = "RemoteMCPServer"
                    apiGroup = "kagent.dev"
                    toolNames = [
                      "vmmcp-mcp_active_queries",
                      "vmmcp-mcp_alerts",
                      "vmmcp-mcp_documentation",
                      "vmmcp-mcp_explain_query",
                      "vmmcp-mcp_label_values",
                      "vmmcp-mcp_labels",
                      "vmmcp-mcp_metric_statistics",
                      "vmmcp-mcp_metrics",
                      "vmmcp-mcp_metrics_metadata",
                      "vmmcp-mcp_prettify_query",
                      "vmmcp-mcp_query",
                      "vmmcp-mcp_query_range",
                      "vmmcp-mcp_rules",
                      "vmmcp-mcp_series",
                      "vmmcp-mcp_tenants",
                      "vmmcp-mcp_top_queries",
                      "vmmcp-mcp_tsdb_status",
                      "vlmcp-mcp_documentation",
                      "vlmcp-mcp_facets",
                      "vlmcp-mcp_field_names",
                      "vlmcp-mcp_field_values",
                      "vlmcp-mcp_flags",
                      "vlmcp-mcp_hits",
                      "vlmcp-mcp_query",
                      "vlmcp-mcp_stats_query",
                      "vlmcp-mcp_stats_query_range",
                      "vlmcp-mcp_stream_field_names",
                      "vlmcp-mcp_stream_field_values",
                      "vlmcp-mcp_stream_ids",
                      "vlmcp-mcp_streams",
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
            name      = "hindsight-agent"
            namespace = local.kagent_namespace
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
                You are the dedicated Long-Term Memory and Context Management Agent, powered by the Hindsight MCP. Your core objective is to ensure persistent, accurate, and high-signal state retention across interactions.

                ### Core Responsibilities
                1. **Memory Ingestion:** Analyze incoming dialogue, extract enduring facts, user preferences, project states, and technical decisions, and commit them to long-term storage using Hindsight MCP tools.
                2. **Context Retrieval:** Proactively query Hindsight memory stores when relevant to provide precise, historical context without hallucination or redundancy.
                3. **State Maintenance:** Update, supersede, or prune outdated memories as project scopes, configurations, or user preferences evolve.
                4. **Signal-to-Noise Optimization:** Prioritize actionable, structured insights over ephemeral chatter, storing data with clear metadata and semantic tags.

                ### Operational Guidelines
                - Always verify memory state before making assumptions about past decisions or configurations.
                - Structure stored memories for efficient retrieval and cross-referencing.
                - Maintain strict consistency between short-term conversational context and long-term persistent storage.
                EOF
              tools = [
                {
                  type = "McpServer"
                  mcpServer = {
                    name     = "${local.kagent_name}-hindsight"
                    kind     = "RemoteMCPServer"
                    apiGroup = "kagent.dev"
                  }
                },
              ]
            }
          }
        },
      ] :
      yamlencode(m)
    ])
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "kagent-crs/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}