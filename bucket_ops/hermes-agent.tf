resource "minio_s3_bucket" "hermes-agent" {
  bucket         = "hermes-agent"
  acl            = "private"
  force_destroy  = true
  object_locking = false
}

resource "minio_iam_user" "hermes-agent" {
  name          = "hermes-agent"
  force_destroy = true
}

resource "minio_iam_policy" "hermes-agent" {
  name = "hermes-agent"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload",
        ]
        Resource = [
          minio_s3_bucket.hermes-agent.arn,
          "${minio_s3_bucket.hermes-agent.arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "hermes-agent" {
  user_name   = minio_iam_user.hermes-agent.id
  policy_name = minio_iam_policy.hermes-agent.id
}

resource "random_password" "hermes-agent-auth-token" {
  length           = 32
  override_special = "-_"
}

module "hermes-agent" {
  source    = "./modules/hermes-agent"
  name      = "hermes-agent"
  namespace = "default"
  images = {
    hermes-agent = {
      repository = "reg.cluster.internal/randomcoww/hermes-mnemosyne"
      tag        = "v2026.8.16.1786969225@sha256:691bbc0ad83932b15784ac96e036ddf00b82a2697d40d8b31b38e34651a96f2d" # renovate: datasource=docker depName=reg.cluster.internal/randomcoww/hermes-mnemosyne
    }
    hermes-webui = {
      repository = "ghcr.io/nesquena/hermes-webui"
      tag        = "0.52.262@sha256:52644509d2967489acec78fa70d3d3450e07dbd60e738b2b5753ba97dd166bca" # renovate: datasource=docker depName=ghcr.io/nesquena/hermes-webui
    }
  }
  # TODO: investigate apptainer and podman for agent terminal
  extra_configs = {
    agent = {
      tool_use_enforcement = true
      reasoning_effort     = "medium"
      max_turns            = 300
    }
    stt = {
      enabled  = true
      provider = "groq"
    }
    model = {
      default        = "qwen-3-8-27b"
      provider       = "custom"
      base_url       = "$${OPENAI_BASE_URL}"
      api_key        = "$${OPENAI_API_KEY}"
      context_length = 262144
    }
    web = {
      search_backend  = "searxng"
      extract_backend = "camofox"
    }
    browser = {
      camofox_url = "$${CAMOFOX_URL}"
    }
    mcp_servers = {
      kubernetes = {
        url = "https://${local.kubernetes-mcp_name}.${local.kubernetes-mcp_namespace}:${local.kubernetes-mcp_port}/mcp"
        client_cert = [
          "$${INTERNAL_CLIENT_CERT_PATH}",
          "$${INTERNAL_CLIENT_KEY_PATH}",
        ]
        timeout         = 300
        connect_timeout = 30
      }
      alpaca = {
        command = "uvx"
        args = [
          "alpaca-mcp-server",
        ]
        env = {
          ALPACA_API_KEY     = "$${ALPACA_API_KEY}"
          ALPACA_SECRET_KEY  = "$${ALPACA_SECRET_KEY}"
          ALPACA_PAPER_TRADE = "true"
          ALPACA_TOOLSETS = join(",", [
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
          ])
        }
        timeout         = 300
        connect_timeout = 30
      }
      victoria-metrics = {
        url             = "http://${local.victoria-metrics-mcp_name}-victoria-metrics-mcp.${local.victoria-metrics_namespace}:${local.victoria-metrics-mcp_port}/mcp"
        timeout         = 300
        connect_timeout = 30
      }
      victoria-logs = {
        url             = "http://${local.victoria-logs-mcp_name}-victoria-logs-mcp.${local.victoria-metrics_namespace}:${local.victoria-logs-mcp_port}/mcp"
        timeout         = 300
        connect_timeout = 30
      }
    }
    # https://github.com/AxDSan/mnemosyne/blob/main/docs/hermes-integration.md
    memory = {
      provider = "mnemosyne"
    }
    plugins = {
      enabled = [
        "memory/mnemosyne",
      ]
    }
    auxiliary = {
      title_generation = {
        timeout          = 600
        provider         = "custom"
        model            = "qwen-3-5-4b:low"
        reasoning_effort = "low"
      }
      vision = {
        timeout  = 600
        provider = "custom"
        model    = "qwen-3-5-4b:low"
      }
      compression = {
        timeout  = 600
        provider = "custom"
        model    = "qwen-3-5-4b:low"
      }
      approval = {
        timeout          = 600
        provider         = "custom"
        model            = "qwen-3-5-4b:low"
        reasoning_effort = "low"
      }
      web_extract = {
        timeout          = 600
        provider         = "custom"
        model            = "qwen-3-5-4b:low"
        reasoning_effort = "low"
      }
      triage_specifier = {
        timeout  = 600
        provider = "custom"
        model    = "qwen-3-5-4b:low"
      }
      profile_describer = {
        timeout          = 600
        provider         = "custom"
        model            = "qwen-3-5-4b:low"
        reasoning_effort = "low"
      }
      curator = {
        timeout  = 600
        provider = "custom"
        model    = "qwen-3-5-4b:low"
      }
    }
    group_sessions_per_user = false
    platforms = {
      slack = {
        reply_to_mode = "first"
        extra = {
          reply_in_thread = true
          reply_broadcast = false
        }
      }
    }
    slack = {
      require_mention = true
      strict_mention  = true
    }
    skills = {
      disabled = sort([
        "xurl",
        "openhue",
        "airtable",
        "box",
        "document-to-action-items",
        "docx",
        "google-workspace",
        "maps",
        "meeting-action-items",
        "notion",
        "xlsx",
        "weekly-review-planning",
        "teams-meeting-pipeline",
        "obsidian",
        "songsee",
        "email-inbox-triage",
        "himalaya",
        "touchdesigner-mcp",
        "songwriting-and-ai-music",
        "sketch",
        "pretext",
        "popular-web-designs",
        "p5js",
        "manim-video",
        "humanizer",
        "excalidraw",
        "design-md",
        "comfyui",
        "claude-design",
        "baoyu-infographic",
        "ascii-video",
        "ascii-art",
        "architecture-diagram",
        "claude-code",
        "codex",
        "computer-use",
        "merge-reconciler",
        "opencode",
        "gif-search",
        "youtube-content",
        "evaluating-llms-harness",
        "huggingface-hub",
        "serving-llms-vllm",
        "weights-and-biases",
        "nano-pdf",
        "ocr-and-documents",
        "pdf",
        "powerpoint",
        "product-price-monitor",
        "session-librarian",
        "arxiv",
        "blocked-page-recovery",
        "blogwatcher",
        "competitor-news-monitor",
        "grounded-citations",
        "llm-wiki",
        "polymarket",
        "research-paper-writing",
        "web-retrieval",
        "llama-cpp",
      ])
    }
  }
  extra_config_envs = { # set in hermes agent .env file
    OPENAI_BASE_URL                     = "https://${local.endpoints.llama-cpp.hostname}/v1"
    OPENAI_API_KEY                      = random_password.llama-cpp-auth-token.result
    SEARXNG_URL                         = "http://${local.searxng_name}.${local.searxng_namespace}:${local.searxng_port}"
    CAMOFOX_URL                         = "http://${local.camofox-browser_name}.${local.camofox-browser_namespace}:${local.camofox-browser_port}"
    CAMOFOX_API_KEY                     = random_password.camofox-browser-auth-token.result
    HERMES_TIMEZONE                     = local.timezone
    GITHUB_TOKEN                        = var.github_mcp_token
    API_SERVER_MODEL_NAME               = "hermes-agent"
    API_SERVER_KEY                      = random_password.hermes-agent-auth-token.result
    SLACK_BOT_TOKEN                     = var.slack_bot_token
    SLACK_APP_TOKEN                     = var.slack_app_token
    SLACK_ALLOWED_USERS                 = var.slack_allowed_users
    SLACK_HOME_CHANNEL                  = var.slack_home_channel
    SLACK_HOME_CHANNEL_NAME             = "bot"
    AUXILIARY_VISION_PROVIDER           = "auto"
    HERMES_API_CALL_STALE_TIMEOUT       = "1800s"                                                    # default 90s times out with cronjobs
    HERMES_CRON_TIMEOUT                 = 0                                                          # unlimited
    HERMES_DASHBOARD_OIDC_CLIENT_ID     = local.authelia_oidc_clients.hermes-dashboard.client_id     # only used if HERMES_DASHBOARD=true
    HERMES_DASHBOARD_OIDC_CLIENT_SECRET = local.authelia_oidc_clients.hermes-dashboard.client_secret # only used if HERMES_DASHBOARD=true
    HERMES_DASHBOARD_OIDC_ISSUER        = "https://${local.endpoints.authelia.hostname}"             # only used if HERMES_DASHBOARD=true
    HERMES_DASHBOARD_PUBLIC_URL         = "https://${local.endpoints.hermes-agent.hostname}"         # only used if HERMES_DASHBOARD=true
    GROQ_BASE_URL                       = "https://${local.endpoints.llama-cpp.hostname}/v1"         # passing this in as groq may only work because it expects the same whisper-large-v3-turbo model that I'm using
    GROQ_API_KEY                        = random_password.llama-cpp-auth-token.result
    STT_GROQ_MODEL                      = "whisper-large-v3-turbo"
    # custom vars #
    ALPACA_API_KEY    = var.alpaca_api_key
    ALPACA_SECRET_KEY = var.alpaca_secret_key
  }
  extra_agent_envs = { # passed to hermes agent container
    "TZ" = local.timezone
  }
  extra_webui_envs = { # unique env passed to hermes webui container
    HERMES_WEBUI_GATEWAY_API_KEY = random_password.hermes-agent-auth-token.result
    # TODO: enable OIDC after https://github.com/nesquena/hermes-webui/pull/6164 https://github.com/nesquena/hermes-webui/pull/6286
    # HERMES_WEBUI_OIDC_CLIENT_ID     = local.authelia_oidc_clients.hermes-dashboard.client_id
    # HERMES_WEBUI_OIDC_CLIENT_SECRET = local.authelia_oidc_clients.hermes-dashboard.client_secret
    # HERMES_WEBUI_OIDC_ISSUER        = "https://${local.endpoints.authelia.hostname}"
    # HERMES_WEBUI_OIDC_ALLOW_CLAIM   = "group"
    # HERMES_WEBUI_OIDC_ALLOW_VALUES  = "hermes-admin"
  }
  ca_issuer_name   = local.cert_issuers.ca_internal
  ingress_hostname = local.endpoints.hermes-agent.hostname
  gateway_ref = {
    name      = local.services.cilium.name
    namespace = local.services.cilium.namespace
  }
  minio_endpoint = "https://${local.services.minio.name}.${local.services.minio.namespace}:${local.service_ports.minio}"
  minio_bucket   = "hermes-agent"
  minio_user     = minio_iam_user.hermes-agent
}

resource "minio_s3_object" "fluxcd-hermes-agent" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.hermes-agent.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "hermes-agent/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}

# outputs

output "hermes-agent" {
  value = {
    base_url = "https://${local.endpoints.hermes-agent.hostname}/v1"
    api_key  = random_password.hermes-agent-auth-token.result
  }
  sensitive = true
}