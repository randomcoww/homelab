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

resource "random_password" "hermes-agent-api-key" {
  length           = 32
  override_special = "-_"
}

module "hermes-agent" {
  source    = "./modules/hermes-agent"
  name      = "hermes-agent"
  namespace = "default"
  images = {
    hermes-agent = {
      repository = "docker.io/nousresearch/hermes-agent"
      tag        = "v2026.8.31@sha256:64923faeae267792bf9bf87fe3b4c4869e35004e360c7df01730ad801b74d524" # renovate: datasource=docker depName=docker.io/nousresearch/hermes-agent
    }
    hermes-webui = {
      repository = "ghcr.io/nesquena/hermes-webui"
      tag        = "0.52.264@sha256:1cbd42331e2046706230310e5fa0db537860536b87e7011630d4d4b6eebab2e2" # renovate: datasource=docker depName=ghcr.io/nesquena/hermes-webui
    }
    litestream = {
      repository = "docker.io/litestream/litestream"
      tag        = "0.5.17@sha256:4b02b9859a6b6b4087d8b8944e15f7e984bd7957cba322bbeee38b0e27b9656a" # renovate: datasource=docker depName=docker.io/litestream/litestream
    }
  }
  juicefs_client_tls_path = local.juicefs_client_tls_path
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
      search_backend = "searxng"
    }
    browser = {
      camofox_url = "$${CAMOFOX_URL}"
    }
    timeouts = {
      tools = {
        concurrent_batch = 600
        sequential_call  = 600
      }
    }
    mcp_servers = {
      agentgateway = {
        url             = "https://${local.endpoints.agentgateway.hostname}/mcp"
        timeout         = 300
        connect_timeout = 90
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
    }
    # https://github.com/AxDSan/mnemosyne/blob/main/docs/hermes-integration.md
    memory = {
      provider = "hindsight"
    }
    auxiliary = {
      title_generation = {
        timeout          = 600
        provider         = "custom"
        model            = "granite-4-2-3b"
        reasoning_effort = "low"
      }
      # vision = {
      #   timeout  = 600
      #   provider = "custom"
      #   model    = "granite-4-2-3b"
      # }
      compression = {
        timeout  = 600
        provider = "custom"
        model    = "granite-4-2-3b"
      }
      approval = {
        timeout          = 600
        provider         = "custom"
        model            = "granite-4-2-3b"
        reasoning_effort = "low"
      }
      web_extract = {
        timeout          = 600
        provider         = "custom"
        model            = "granite-4-2-3b"
        reasoning_effort = "low"
      }
      triage_specifier = {
        timeout  = 600
        provider = "custom"
        model    = "granite-4-2-3b"
      }
      profile_describer = {
        timeout          = 600
        provider         = "custom"
        model            = "granite-4-2-3b"
        reasoning_effort = "low"
      }
      curator = {
        timeout  = 600
        provider = "custom"
        model    = "granite-4-2-3b"
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
    gateway = {
      platforms = {
        slack = {
          gateway_restart_notification = false
        }
      }
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
    OPENAI_BASE_URL                     = "https://${local.endpoints.agentgateway.hostname}/v1"
    OPENAI_API_KEY                      = random_password.llama-cpp-api-key.result
    SEARXNG_URL                         = "http://${local.searxng_name}.${local.searxng_namespace}:${local.searxng_port}"
    CAMOFOX_URL                         = "http://${local.camofox-browser_name}.${local.camofox-browser_namespace}:${local.camofox-browser_port}"
    CAMOFOX_API_KEY                     = random_password.camofox-browser-auth-token.result
    HERMES_TIMEZONE                     = local.timezone
    GITHUB_TOKEN                        = var.github_mcp_token
    API_SERVER_MODEL_NAME               = "hermes-agent"
    API_SERVER_KEY                      = random_password.hermes-agent-api-key.result
    SLACK_BOT_TOKEN                     = var.slack_bot_token
    SLACK_APP_TOKEN                     = var.slack_app_token
    SLACK_ALLOWED_USERS                 = var.slack_allowed_users
    SLACK_HOME_CHANNEL                  = var.slack_home_channel
    SLACK_HOME_CHANNEL_NAME             = "bot"
    AUXILIARY_VISION_PROVIDER           = "auto"
    HERMES_AGENT_TIMEOUT                = 3600
    HERMES_CRON_TIMEOUT                 = 3600
    HERMES_API_TIMEOUT                  = 1800
    HERMES_API_CALL_STALE_TIMEOUT       = 1800
    HERMES_STREAM_READ_TIMEOUT          = 300
    HERMES_DASHBOARD_OIDC_CLIENT_ID     = local.authelia_oidc_clients.hermes-dashboard.client_id     # only used if HERMES_DASHBOARD=true
    HERMES_DASHBOARD_OIDC_CLIENT_SECRET = local.authelia_oidc_clients.hermes-dashboard.client_secret # only used if HERMES_DASHBOARD=true
    HERMES_DASHBOARD_OIDC_ISSUER        = "https://${local.endpoints.authelia.hostname}"             # only used if HERMES_DASHBOARD=true
    HERMES_DASHBOARD_PUBLIC_URL         = "https://${local.endpoints.hermes-agent.hostname}"         # only used if HERMES_DASHBOARD=true
    GROQ_BASE_URL                       = "https://${local.endpoints.agentgateway.hostname}/v1"      # passing this in as groq may only work because it expects the same whisper-large-v3-turbo model that I'm using
    GROQ_API_KEY                        = random_password.llama-cpp-api-key.result
    STT_GROQ_MODEL                      = "whisper-large-v3-turbo"
    # hindsight #
    HINDSIGHT_API_URL      = "http://${local.hindsight_name}-api.${local.hindsight_namespace}:${local.hindsight_port}"
    HINDSIGHT_MODE         = "local_external"
    HINDSIGHT_TIMEOUT      = 900
    HINDSIGHT_BUDGET       = "low"
    HINDSIGHT_IDLE_TIMEOUT = 0 # unlimited
    # custom vars #
    ALPACA_API_KEY    = var.alpaca_api_key
    ALPACA_SECRET_KEY = var.alpaca_secret_key
  }
  extra_agent_envs = { # passed to hermes agent container
    "TZ" = local.timezone
  }
  extra_webui_envs = { # unique env passed to hermes webui container
    HERMES_WEBUI_GATEWAY_API_KEY = random_password.hermes-agent-api-key.result
    # TODO: enable OIDC after https://github.com/nesquena/hermes-webui/pull/6164 https://github.com/nesquena/hermes-webui/pull/6286
    # HERMES_WEBUI_OIDC_CLIENT_ID     = local.authelia_oidc_clients.hermes-dashboard.client_id
    # HERMES_WEBUI_OIDC_CLIENT_SECRET = local.authelia_oidc_clients.hermes-dashboard.client_secret
    # HERMES_WEBUI_OIDC_ISSUER        = "https://${local.endpoints.authelia.hostname}"
    # HERMES_WEBUI_OIDC_ALLOW_CLAIM   = "group"
    # HERMES_WEBUI_OIDC_ALLOW_VALUES  = "hermes-admin"
  }
  ssh_ca   = data.terraform_remote_state.host.outputs.ssh_ca
  ssh_user = "agent"

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

output "hermes-agent-api-key" {
  value     = random_password.hermes-agent-api-key.result
  sensitive = true
}