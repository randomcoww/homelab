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
      tag        = "v2026.8.3.1785964257@sha256:e76689bfde8765b027ef277322b07767d04e1699d1e945daf3ac07596ae5b00d" # renovate: datasource=docker depName=reg.cluster.internal/randomcoww/hermes-mnemosyne
    }
  }
  # TODO: investigate apptainer and podman for agent terminal
  extra_configs = {
    agent = {
      tool_use_enforcement = true
      reasoning_effort     = "xhigh"
    }
    stt = {
      enabled  = true
      provider = "groq"
    }
    model = {
      default        = "qwen-3-6-27b"
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
      github = {
        url = "https://api.githubcopilot.com/mcp"
        headers = {
          Authorization = "Bearer $${GITHUB_TOKEN}"
        }
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
        url             = "http://${local.victoria-metrics-mcp_name}-victoria-metrics-mcp.${local.victoria-metrics-mcp_namespace}:${local.victoria-metrics-mcp_port}/mcp"
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
      vision = {
        timeout = 1800
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
  }
  extra_config_envs = {
    OPENAI_BASE_URL                     = "https://${local.httproutes.llama-cpp.hostname}/v1"
    OPENAI_API_KEY                      = random_password.llama-cpp-auth-token.result
    SEARXNG_URL                         = "http://${local.searxng_name}.${local.searxng_namespace}:${local.searxng_port}"
    CAMOFOX_URL                         = "http://${local.camofox-browser_name}.${local.camofox-browser_namespace}:${local.camofox-browser_port}"
    CAMOFOX_API_KEY                     = random_password.camofox-browser-auth-token.result
    HERMES_TIMEZONE                     = local.timezone
    GITHUB_TOKEN                        = var.github_token
    API_SERVER_MODEL_NAME               = "hermes-agent"
    API_SERVER_KEY                      = random_password.hermes-agent-auth-token.result
    SLACK_BOT_TOKEN                     = var.slack_bot_token
    SLACK_APP_TOKEN                     = var.slack_app_token
    SLACK_ALLOWED_USERS                 = var.slack_allowed_users
    SLACK_HOME_CHANNEL                  = var.slack_home_channel
    SLACK_HOME_CHANNEL_NAME             = "bot"
    AUXILIARY_VISION_PROVIDER           = "auto"
    HERMES_DASHBOARD_OIDC_CLIENT_ID     = local.authelia_oidc_clients.hermes-dashboard.client_id
    HERMES_DASHBOARD_OIDC_CLIENT_SECRET = local.authelia_oidc_clients.hermes-dashboard.client_secret
    HERMES_DASHBOARD_OIDC_ISSUER        = "https://${local.httproutes.authelia.hostname}"
    HERMES_DASHBOARD_PUBLIC_URL         = "https://${local.httproutes.hermes-agent.hostname}"
    # TODO: STT config - using groq is a hack that may only work because it expects the same whisper-large-v3-turbo model that I'm using
    GROQ_BASE_URL  = "https://${local.httproutes.llama-cpp.hostname}/v1"
    STT_GROQ_MODEL = "whisper-large-v3-turbo"
    GROQ_API_KEY   = random_password.llama-cpp-auth-token.result
    # custom vars #
    ALPACA_API_KEY    = var.alpaca_api_key
    ALPACA_SECRET_KEY = var.alpaca_secret_key
  }
  extra_agent_envs = {
    "TZ" = local.timezone
  }
  ca_issuer_name   = local.cert_issuers.ca_internal
  ingress_hostname = local.httproutes.hermes-agent.hostname
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
    base_url = "https://${local.httproutes.hermes-agent.hostname}/v1"
    api_key  = random_password.hermes-agent-auth-token.result
  }
  sensitive = true
}