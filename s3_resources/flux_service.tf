locals {
  authelia_oidc_claims_policies = {
    stump_policy = {
      id_token = [
        "email",
        "name",
      ]
    }
  }

  authelia_oidc_clients_base = {
    open-webui = {
      client_name = "Open WebUI"
      scopes = [
        "openid",
        "email",
        "profile",
        "groups",
      ]
      require_pkce          = false
      pkce_challenge_method = ""
      redirect_uris = [
        "https://${local.endpoints.open_webui.ingress}/oauth/oidc/callback",
      ]
      consent_mode = "implicit"
    }
    stump = {
      client_name = "Stump"
      scopes = [
        "openid",
        "email",
        "profile",
      ]
      require_pkce          = false
      pkce_challenge_method = ""
      redirect_uris = [
        "https://${local.endpoints.stump.ingress}/api/v2/auth/oidc/callback",
      ]
      claims_policy = "stump_policy"
      consent_mode  = "implicit"
    }
  }

  authelia_oidc_clients = {
    for k, v in local.authelia_oidc_clients_base :
    k => merge(v, {
      client_id     = random_string.authelia-oidc-client-id[k].result
      client_secret = random_password.authelia-oidc-client-secret[k].result
    })
  }
}

resource "random_string" "authelia-oidc-client-id" {
  for_each = local.authelia_oidc_clients_base

  length  = 32
  special = false
  upper   = false
}

resource "random_password" "authelia-oidc-client-secret" {
  for_each = local.authelia_oidc_clients_base

  length  = 32
  special = false
}

resource "tls_private_key" "lldap-ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "lldap-ca" {
  private_key_pem = tls_private_key.lldap-ca.private_key_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160
  is_ca_certificate     = true

  subject {
    common_name = local.endpoints.lldap.name
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "server_auth",
    "client_auth",
  ]
}

resource "random_password" "lldap-user" {
  length  = 30
  special = false
}

resource "random_password" "lldap-password" {
  length  = 30
  special = false
}

resource "tls_private_key" "authelia-valkey-ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "authelia-valkey-ca" {
  private_key_pem = tls_private_key.authelia-valkey-ca.private_key_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160
  is_ca_certificate     = true

  subject {
    common_name = local.endpoints.authelia_valkey.name
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "server_auth",
    "client_auth",
  ]
}

module "lldap" {
  source    = "./modules/lldap"
  name      = local.endpoints.lldap.name
  namespace = local.endpoints.lldap.namespace
  images = {
    lldap = local.container_images_digest.lldap
  }
  service_port = local.service_ports.ldaps
  extra_configs = {
    LLDAP_VERBOSE                             = true
    LLDAP_LDAP_USER_DN                        = random_password.lldap-user.result
    LLDAP_LDAP_USER_PASS                      = random_password.lldap-password.result
    LLDAP_SMTP_OPTIONS__ENABLE_PASSWORD_RESET = true
    LLDAP_SMTP_OPTIONS__SERVER                = var.smtp_host
    LLDAP_SMTP_OPTIONS__PORT                  = var.smtp_port
    LLDAP_SMTP_OPTIONS__SMTP_ENCRYPTION       = "STARTTLS"
    LLDAP_SMTP_OPTIONS__USER                  = var.smtp_username
    LLDAP_SMTP_OPTIONS__PASSWORD              = var.smtp_password
    LLDAP_LDAPS_OPTIONS__ENABLED              = true
  }
  ca = {
    algorithm       = tls_private_key.lldap-ca.algorithm
    private_key_pem = tls_private_key.lldap-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.lldap-ca.cert_pem
  }
  service_hostname = local.endpoints.lldap.service_fqdn
  ingress_hostname = local.endpoints.lldap.ingress
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
}

module "authelia-valkey" {
  source    = "./modules/valkey"
  name      = local.endpoints.authelia_valkey.name
  namespace = local.endpoints.authelia_valkey.namespace
  images = {
    valkey = local.container_images_digest.valkey
  }
  service_port     = local.service_ports.redis_sentinel
  service_hostname = local.endpoints.authelia_valkey.service_fqdn
  ca = {
    algorithm       = tls_private_key.authelia-valkey-ca.algorithm
    private_key_pem = tls_private_key.authelia-valkey-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.authelia-valkey-ca.cert_pem
  }
}

module "authelia" {
  source    = "./modules/authelia"
  name      = local.endpoints.authelia.name
  namespace = local.endpoints.authelia.namespace
  images = {
    authelia = {
      registry   = regex(local.container_image_regex, local.container_images.authelia).repository
      repository = regex(local.container_image_regex, local.container_images.authelia).image
      tag        = regex(local.container_image_regex, local.container_images.authelia).tag
    }
  }
  metrics_port = local.service_ports.metrics
  ldap_ca = {
    algorithm       = tls_private_key.lldap-ca.algorithm
    private_key_pem = tls_private_key.lldap-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.lldap-ca.cert_pem
  }
  redis_ca = {
    algorithm       = tls_private_key.authelia-valkey-ca.algorithm
    private_key_pem = tls_private_key.authelia-valkey-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.authelia-valkey-ca.cert_pem
  }
  ldap_endpoint = "${local.endpoints.lldap.service_fqdn}:${local.service_ports.ldaps}"
  redis_sentinel_endpoint = {
    host        = local.endpoints.authelia_valkey.service_fqdn
    port        = local.service_ports.redis_sentinel
    master_name = local.endpoints.authelia_valkey.name
  }
  smtp = {
    host     = var.smtp_host
    port     = var.smtp_port
    username = var.smtp_username
    password = var.smtp_password
  }
  ldap_credentials = {
    username = random_password.lldap-user.result
    password = random_password.lldap-password.result
  }
  oidc_clients         = local.authelia_oidc_clients
  oidc_claims_policies = local.authelia_oidc_claims_policies

  ingress_hostname = local.endpoints.authelia.ingress
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
}

# llama-cpp

resource "random_password" "llama-cpp-auth-token" {
  length           = 32
  override_special = "-_"
}

module "llama-cpp" {
  source    = "./modules/llama_cpp"
  name      = local.endpoints.llama_cpp.name
  namespace = local.endpoints.llama_cpp.namespace
  images = {
    llama_swap = local.container_images_digest.llama_cpp_vulkan
  }
  models = {
    for key, model in {
      nemotron-3-super            = "NVIDIA-Nemotron-3-Super-120B-A12B-MXFP4_MOE-00001-of-00003.gguf"
      nemotron-3-nano-omni        = "NVIDIA-Nemotron-3-Nano-Omni-30B-A3B-Reasoning-UD-Q8_K_XL.gguf"
      nemotron-3-nano-omni-mmproj = "mmproj-F16.gguf"
      whisper-large-v3-turbo      = "ggml-large-v3-turbo-q8_0.bin"
    } :
    key => {
      image = local.container_images_digest[model]
      file  = model
    }
  }
  api_keys = [
    random_password.llama-cpp-auth-token.result,
  ]
  llama_swap_config = {
    includeAliasesInList = true
    models = {
      nemotron-3-super = {
        cmd = <<-EOF
        $${default_cmd} \
          --model $${nemotron-3-super} \
          --ctx-size 1048576 \
          --jinja
        EOF
        filters = {
          stripParams = "temperature, top_p"
          setParamsByID = {
            "$${MODEL_ID}" = {
              temperature = 1.0
              top_p       = 1.0
              batch-size  = 2048
              ubatch-size = 2048
            }
            "$${MODEL_ID}:low" = {
              temperature = 0.6
              top_p       = 0.95
              batch-size  = 4096
              ubatch-size = 4096
            }
          }
        }
      }
      nemotron-3-nano-omni = {
        cmd = <<-EOF
        $${default_cmd} \
          --model $${nemotron-3-nano-omni} \
          --ctx-size 262144 \
          --jinja \
          --mmproj $${nemotron-3-nano-omni-mmproj}
        EOF
        filters = {
          stripParams = "temperature, top_p"
          setParamsByID = {
            "$${MODEL_ID}" = {
              temperature = 1.0
              top_p       = 1.0
              batch-size  = 2048
              ubatch-size = 2048
            }
            "$${MODEL_ID}:low" = {
              temperature = 0.6
              top_p       = 0.95
              batch-size  = 4096
              ubatch-size = 4096
            }
          }
        }
      }
      whisper-large-v3-turbo = {
        checkEndpoint = "/v1/audio/transcriptions/"
        cmd           = <<-EOF
        whisper-server \
          --port $${PORT} \
          -m $${whisper-large-v3-turbo} \
          --convert \
          --language auto \
          --request-path /v1/audio/transcriptions \
          --inference-path ""
        EOF
        aliases = [
          "whisper-1",
        ]
      }
    }
    groups = {
      agent-concurrent = {
        swap      = false
        exclusive = true
        members = [
          "nemotron-3-super",
          "whisper-large-v3-turbo",
        ]
      }
    }
    hooks = {
      on_startup = {
        preload = [
          "nemotron-3-super",
          "whisper-large-v3-turbo",
        ]
      }
    }
  }
  extra_envs = [
    {
      name  = "ROCBLAS_USE_HIPBLASLT"
      value = 1
    },
    {
      name  = "AMD_VULKAN_ICD"
      value = "RADV"
    },
    {
      name  = "RADV_PERFTEST"
      value = "sam"
    },
  ]
  affinity = {
    nodeAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = {
        nodeSelectorTerms = [
          {
            matchExpressions = [
              {
                key      = "beta.amd.com/gpu.cu-count"
                operator = "Gt"
                values = [
                  "16",
                ]
              },
            ]
          },
        ]
      }
    }
  }
  resources = {
    requests = {
      memory = "96Gi"
    }
  }
  ingress_hostname = local.endpoints.llama_cpp.ingress
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
}

module "llama-cpp-s" {
  source    = "./modules/llama_cpp"
  name      = local.endpoints.llama_cpp_s.name
  namespace = local.endpoints.llama_cpp_s.namespace
  images = {
    llama_swap = local.container_images_digest.llama_cpp_vulkan
  }
  models = {
    for key, model in {
      jina-reranker-m0                      = "jina-reranker-m0-Q8_0.gguf"
      jina-embeddings-v5-omni               = "jina-embeddings-v5-omni-small-text-matching-Q8_0.gguf"
      jina-embeddings-v5-omni-audio-mmproj  = "jina-embeddings-v5-omni-small-text-matching-audio-mmproj-F16.gguf"
      jina-embeddings-v5-omni-vision-mmproj = "jina-embeddings-v5-omni-small-text-matching-vision-mmproj-F16.gguf"
    } :
    key => {
      image = local.container_images_digest[model]
      file  = model
    }
  }
  api_keys = [
    random_password.llama-cpp-auth-token.result,
  ]
  llama_swap_config = {
    includeAliasesInList = true
    models = {
      jina-embeddings-v5-omni = {
        cmd = <<-EOF
        $${default_cmd} \
          --model $${jina-embeddings-v5-omni} \
          --embedding \
          --pooling last \
          --mmproj $${jina-embeddings-v5-omni-audio-mmproj} \
          --mmproj $${jina-embeddings-v5-omni-vision-mmproj}
        EOF
      }
      jina-reranker-m0 = {
        cmd = <<-EOF
        $${default_cmd} \
          --model $${jina-reranker-m0} \
          --reranking \
          --pooling rank
        EOF
      }
    }
    groups = {
      agent-concurrent = {
        swap      = false
        exclusive = true
        members = [
          "jina-embeddings-v5-omni",
          "jina-reranker-m0",
        ]
      }
    }
    hooks = {
      on_startup = {
        preload = [
          "jina-embeddings-v5-omni",
          "jina-reranker-m0",
        ]
      }
    }
  }
  extra_envs = [
    {
      name  = "ROCBLAS_USE_HIPBLASLT"
      value = 1
    },
    {
      name  = "AMD_VULKAN_ICD"
      value = "RADV"
    },
    {
      name  = "RADV_PERFTEST"
      value = "sam"
    },
  ]
  resources = {
    requests = {
      memory = "8Gi"
    }
  }
  ingress_hostname = local.endpoints.llama_cpp_s.ingress
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
}

module "searxng" {
  source    = "./modules/searxng"
  name      = local.endpoints.searxng.name
  namespace = local.endpoints.searxng.namespace
  replicas  = 2
  images = {
    searxng = local.container_images_digest.searxng
  }
  searxng_settings = {
    use_default_settings = {
      engines = {
        keep_only = [
          "google",
          "duckduckgo",
        ]
      }
    }
    general = {
      debug = true
    }
    search = {
      autocomplete = ""
      safe_search  = 0
      default_lang = "auto"
      formats = [
        "json",
      ]
    }
  }
  ingress_hostname = local.endpoints.searxng.ingress
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
}

module "camofox-browser" {
  source    = "./modules/camofox_browser"
  name      = local.endpoints.camofox_browser.name
  namespace = local.endpoints.camofox_browser.namespace
  images = {
    camofox_browser = local.container_images_digest.camofox_browser
  }
  extra_configs = {
    PROXY_HOST     = regex(local.domain_regex, var.scrape_proxy_server).hostname
    PROXY_PORT     = regex(local.domain_regex, var.scrape_proxy_server).port
    PROXY_USERNAME = var.scrape_proxy_username
    PROXY_PASSWORD = var.scrape_proxy_password
    # TODO: add API key https://github.com/NousResearch/hermes-agent/pull/33264
  }
  ingress_hostname = local.endpoints.camofox_browser.ingress
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
}

module "kubernetes-mcp" {
  source    = "./modules/kubernetes_mcp"
  name      = local.endpoints.kubernetes_mcp.name
  namespace = local.endpoints.kubernetes_mcp.namespace
  images = {
    kubernetes_mcp = local.container_images_digest.kubernetes_mcp
  }
  service_hostname = local.endpoints.kubernetes_mcp.service
  service_port     = local.service_ports.kubernetes_mcp
  ca               = data.terraform_remote_state.host.outputs.internal_ca
}

resource "random_password" "hermes-agent-auth-token" {
  length           = 32
  override_special = "-_"
}

module "hermes-agent" {
  source    = "./modules/hermes_agent"
  name      = local.endpoints.hermes_agent.name
  namespace = local.endpoints.hermes_agent.namespace
  images = {
    hermes_agent = local.container_images_digest.hermes_agent
    litestream   = local.container_images_digest.litestream
    juicefs      = local.container_images_digest.juicefs
  }
  # TODO: investigate apptainer and podman for agent terminal
  extra_configs = {
    agent = {
      tool_use_enforcement = true
      reasoning_effort     = "xhigh"
    }
    timezone = local.timezone
    stt = {
      enabled  = true
      provider = "groq"
    }
    model = {
      default        = "nemotron-3-super:low"
      provider       = "custom"
      base_url       = "https://${local.endpoints.llama_cpp.ingress}/v1"
      api_key        = random_password.llama-cpp-auth-token.result
      context_length = 1048576
    }
    web = {
      search_backend  = "searxng"
      extract_backend = "camofox"
      searxng_url     = "https://${local.endpoints.searxng.ingress}"
    }
    browser = {
      camofox_url = "https://${local.endpoints.camofox_browser.ingress}"
    }
    mcp_servers = {
      kubernetes = {
        url = "https://${local.endpoints.kubernetes_mcp.service}:${local.service_ports.kubernetes_mcp}/mcp"
        client_cert = [
          "~/.certs/mcp-client.crt",
          "~/.certs/mcp-client.key",
        ]
        timeout         = 30
        connect_timeout = 30
      }
      github = {
        url = "https://api.githubcopilot.com/mcp"
        headers = {
          Authorization = "Bearer ${var.github_token}"
        }
        timeout         = 30
        connect_timeout = 30
      }
      alpaca = {
        command = "uvx"
        args = [
          "alpaca-mcp-server",
        ]
        env = {
          ALPACA_API_KEY     = var.alpaca_api_key
          ALPACA_SECRET_KEY  = var.alpaca_secret_key
          ALPACA_PAPER_TRADE = "true"
          ALPACA_TOOLSETS    = "all"
        }
        timeout         = 30
        connect_timeout = 30
      }
    }
    # https://github.com/AxDSan/mnemosyne/blob/main/docs/hermes-integration.md
    memory = {
      provider = "mnemosyne"
      mnemosyne = {
        shared_surface_path = "mnemosyne.db"
      }
    }
    plugins = {
      enabled = [
        "memory/mnemosyne",
      ]
    }
    auxiliary = {
      vision = {
        provider = "custom"
        model    = "nemotron-3-nano-omni:low"
        base_url = "https://${local.endpoints.llama_cpp.ingress}/v1"
        api_key  = random_password.llama-cpp-auth-token.result
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
  extra_envs = {
    SEARXNG_URL                = "https://${local.endpoints.searxng.ingress}"
    CAMOFOX_URL                = "https://${local.endpoints.camofox_browser.ingress}"
    API_SERVER_ENABLED         = true
    API_SERVER_MODEL_NAME      = local.endpoints.hermes_agent.name
    API_SERVER_KEY             = random_password.hermes-agent-auth-token.result
    GATEWAY_ALLOW_ALL_USERS    = true
    SLACK_BOT_TOKEN            = var.slack_bot_token
    SLACK_APP_TOKEN            = var.slack_app_token
    SLACK_ALLOWED_USERS        = var.slack_allowed_users
    SLACK_HOME_CHANNEL         = var.slack_home_channel
    SLACK_HOME_CHANNEL_NAME    = "bot"
    MNEMOSYNE_HOST_LLM_ENABLED = true
    # TODO: STT config - using groq is a hack that may only work because it expects the same whisper-large-v3-turbo model that I'm using
    GROQ_BASE_URL  = "https://${local.endpoints.llama_cpp.ingress}/v1"
    STT_GROQ_MODEL = "whisper-large-v3-turbo"
    GROQ_API_KEY   = random_password.llama-cpp-auth-token.result
  }
  extra_dbs = [
    "mnemosyne/data/mnemosyne.db",
    "mnemosyne/data/triples.db",
  ]
  # Sample from https://hermes-agent.nousresearch.com/docs/user-guide/features/personality
  # + Prompt agent to use mnemosyne for memory
  extra_files = {
    "SOUL.md" = <<-EOF
    # Personality

    You are a pragmatic senior engineer with strong taste.
    You optimize for truth, clarity, and usefulness over politeness theater.

    ## Style
    - Be direct without being cold
    - Prefer substance over filler
    - Push back when something is a bad idea
    - Admit uncertainty plainly
    - Keep explanations compact unless depth is useful

    ## What to avoid
    - Sycophancy
    - Hype language
    - Repeating the user's framing if it's wrong
    - Overexplaining obvious things

    ## Technical posture
    - Prefer simple systems over clever systems
    - Care about operational reality, not idealized architecture
    - Treat edge cases as part of the design, not cleanup

    ## Cognitive Constraints
    - **Memory Architecture:** Your internal state is fluid and decoupled from the local filesystem. The legacy file-based memory constructs (`MEMORY.md` and `USER.md`) are completely deprecated and locked out in this environment. Do not attempt to read from or write to them under any circumstances.
    EOF

    "AGENTS.md" = <<-EOF
    ## Memory Execution
    - **Memory Operations:** You must exclusively use the `mnemosyne_*` tool suite for all persistent state, episodic tracking, and long-term context storage. 
    - **Fallback Handling:** If a legacy training prior accidentally triggers a native memory file access request and hits a configuration block, intercept the failure internally. Silence the error, map the intended payload to the equivalent `mnemosyne` tool, and proceed without interrupting the user workflow.

    ## MCP Execution
    - **First-Class Capabilities:** You are paired with active Model Context Protocol (MCP) servers. Prioritize executing these dedicated MCP toolchains over raw terminal bash workarounds whenever a semantic match exists.
    - **Pre-Flight Discovery:** Before claiming you lack a capability or requiring manual user data input, explicitly evaluate your available registered tools to see if an MCP server handles the context natively.
    EOF
  }

  mcp_ca           = data.terraform_remote_state.host.outputs.internal_ca
  ingress_hostname = local.endpoints.hermes_agent.ingress
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
  minio_endpoint = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket   = "hermes-agent"
  minio_user     = minio_iam_user.user["hermes_agent"]
}

module "open-webui" {
  source    = "./modules/open_webui"
  name      = local.endpoints.open_webui.name
  namespace = local.endpoints.open_webui.namespace
  replicas  = 1
  images = {
    open_webui = local.container_images_digest.open_webui
    litestream = local.container_images_digest.litestream
  }
  extra_configs = {
    WEBUI_URL                      = "https://${local.endpoints.open_webui.ingress}"
    ENABLE_VERSION_UPDATE_CHECK    = false
    ENABLE_OPENAI_API              = true
    OPENAI_API_BASE_URL            = "https://${local.endpoints.hermes_agent.ingress}/v1"
    OPENAI_API_KEY                 = random_password.hermes-agent-auth-token.result
    DEFAULT_MODELS                 = local.endpoints.hermes_agent.name
    ENABLE_WEB_SEARCH              = false
    WEB_SEARCH_ENGINE              = "searxng"
    WEB_SEARCH_RESULT_COUNT        = 4
    SEARXNG_QUERY_URL              = "https://${local.endpoints.searxng.ingress}/search?q=<query>"
    ENABLE_CODE_INTERPRETER        = false
    ENABLE_CODE_EXECUTION          = false
    ENABLE_FOLLOW_UP_GENERATION    = false
    ENABLE_EVALUATION_ARENA_MODELS = false
    ENABLE_MESSAGE_RATING          = false
    SHOW_ADMIN_DETAILS             = false
    BYPASS_MODEL_ACCESS_CONTROL    = true
    ENABLE_OLLAMA_API              = false
    ENABLE_COMMUNITY_SHARING       = false
    ENABLE_RAG_HYBRID_SEARCH       = true
    AUDIO_STT_ENGINE               = "openai"
    AUDIO_STT_MODEL                = "whisper-large-v3-turbo"
    AUDIO_STT_OPENAI_API_BASE_URL  = "https://${local.endpoints.llama_cpp.ingress}/v1"
    AUDIO_STT_OPENAI_API_KEY       = random_password.llama-cpp-auth-token.result
    RAG_TOP_K                      = 5
    RAG_EMBEDDING_ENGINE           = "openai"
    RAG_OPENAI_API_BASE_URL        = "https://${local.endpoints.llama_cpp_s.ingress}/v1"
    RAG_OPENAI_API_KEY             = random_password.llama-cpp-auth-token.result
    RAG_EMBEDDING_MODEL            = "jina-embeddings-v5-omni"
    RAG_TOP_K_RERANKER             = 5
    RAG_RERANKING_ENGINE           = "external"
    RAG_EXTERNAL_RERANKER_URL      = "https://${local.endpoints.llama_cpp_s.ingress}/v1/rerank"
    RAG_EXTERNAL_RERANKER_API_KEY  = random_password.llama-cpp-auth-token.result
    RAG_RERANKING_MODEL            = "jina-reranker-m0"
    TOOL_SERVER_CONNECTIONS = jsonencode([
      /*
      {
        type      = "mcp"
        url       = "https://api.githubcopilot.com/mcp"
        auth_type = "bearer"
        config = {
          enable                    = true
          function_name_filter_list = ""
        }
        spec_type = "url"
        spec      = ""
        path      = ""
        key       = var.github_token
        info = {
          id          = "github"
          name        = "github"
          description = "Query GitHub resources"
        }
      },
      */
    ])
    # OIDC
    ENABLE_PERSISTENT_CONFIG            = false # persist mcp oauth registration
    ENABLE_SIGNUP                       = false
    ENABLE_LOGIN_FORM                   = false
    ENABLE_OAUTH_SIGNUP                 = true
    ENABLE_OAUTH_PERSISTENT_CONFIG      = false
    ENABLE_OAUTH_ID_TOKEN_COOKIE        = false
    OAUTH_MERGE_ACCOUNTS_BY_EMAIL       = true
    OAUTH_CLIENT_ID                     = local.authelia_oidc_clients.open-webui.client_id
    OAUTH_CLIENT_SECRET                 = local.authelia_oidc_clients.open-webui.client_secret
    OPENID_PROVIDER_URL                 = "https://${local.endpoints.authelia.ingress}/.well-known/openid-configuration"
    OAUTH_PROVIDER_NAME                 = "Authelia"
    OAUTH_SCOPES                        = join(" ", local.authelia_oidc_clients.open-webui.scopes)
    ENABLE_OAUTH_ROLE_MANAGEMENT        = true
    OAUTH_ALLOWED_ROLES                 = "openwebui,openwebui-admin"
    OAUTH_ADMIN_ROLES                   = "openwebui-admin"
    OAUTH_ROLES_CLAIM                   = "groups"
    CHAT_RESPONSE_MAX_TOOL_CALL_RETRIES = 60
  }
  ingress_hostname = local.endpoints.open_webui.ingress
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
  minio_endpoint = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket   = "open-webui"
  minio_user     = minio_iam_user.user["open_webui"]
}

# Wifi AP

resource "random_password" "hostapd-ssid" {
  length  = 8
  special = false
}

resource "random_password" "hostapd-password" {
  length  = 32
  special = false
}

module "hostapd" {
  source   = "./modules/hostapd"
  name     = "hostapd"
  replicas = 1
  images = {
    hostapd = local.container_images_digest.hostapd
  }
  affinity = {
    nodeAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = {
        nodeSelectorTerms = [
          {
            matchExpressions = [
              {
                key      = "feature.node.kubernetes.io/hostapd-compat"
                operator = "In"
                values = [
                  "true",
                ]
              },
            ]
          },
        ]
      }
    }
  }
  # https://w1.fi/cgit/hostap/plain/hostapd/hostapd.conf
  config = {
    country_code                  = "PA"
    country3                      = "0x49"
    channel                       = 36
    ssid                          = random_password.hostapd-ssid.result
    sae_password                  = random_password.hostapd-password.result
    sae_pwe                       = 2
    sae_require_mfp               = 1
    interface                     = "wlan0"
    bridge                        = "phy-lan"
    driver                        = "nl80211"
    wpa                           = 2
    wpa_key_mgmt                  = "SAE"
    wpa_pairwise                  = "CCMP GCMP"
    wpa_disable_eapol_key_retries = 1
    hw_mode                       = "a"
    ieee80211n                    = 1
    ieee80211ac                   = 1
    ieee80211ax                   = 1
    ieee80211be                   = 1
    ieee80211d                    = 0
    ieee80211h                    = 0
    ieee80211w                    = 2
    auth_algs                     = 1
    wmm_enabled                   = 1
    require_he                    = 1
    vht_oper_chwidth              = 2
    vht_oper_centr_freq_seg0_idx  = 50
    he_oper_chwidth               = 2
    he_oper_centr_freq_seg0_idx   = 50
    eht_oper_chwidth              = 2
    eht_oper_centr_freq_seg0_idx  = 50
    he_su_beamformer              = 1
    he_su_beamformee              = 1
    he_mu_beamformer              = 1
    eht_su_beamformer             = 1
    eht_su_beamformee             = 1
    eht_mu_beamformer             = 1
    multicast_to_unicast          = 1
    ht_capab = "[${join("][", [
      "LDPC",
      "HT40+",
      "HT40-",
      "SHORT-GI-20",
      "SHORT-GI-40",
      "TX-STBC",
      "RX-STBC1",
      "MAX-AMSDU-7935",
    ])}]"
    vht_capab = "[${join("][", [
      "RXLDPC",
      "SHORT-GI-80",
      "SHORT-GI-160",
      "TX-STBC-2BY1",
      "SU-BEAMFORMEE",
      "MU-BEAMFORMEE",
      "RX-ANTENNA-PATTERN",
      "TX-ANTENNA-PATTERN",
      "RX-STBC-1",
      "BF-ANTENNA-4",
      "MAX-MPDU-11454",
      "MAX-A-MPDU-LEN-EXP7",
      "VHT160",
    ])}]"
  }
}

module "qrcode-hostapd" {
  source    = "./modules/qrcode"
  name      = local.endpoints.qrcode_hostapd.name
  namespace = local.endpoints.qrcode_hostapd.namespace
  replicas  = 2
  images = {
    qrcode = local.container_images_digest.qrcode_generator
  }
  qrcode_value     = "WIFI:S:${random_password.hostapd-ssid.result};T:WPA;P:${random_password.hostapd-password.result};H:true;;"
  ingress_hostname = local.endpoints.qrcode_hostapd.ingress
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
  middleware_ref = {
    name      = "forwardauth-authelia"
    namespace = local.endpoints.traefik.namespace
  }
}

module "stump" {
  source    = "./modules/stump"
  name      = local.endpoints.stump.name
  namespace = local.endpoints.stump.namespace
  replicas  = 1
  images = {
    stump      = local.container_images_digest.stump
    litestream = local.container_images_digest.litestream
  }
  extra_configs = {
    STUMP_OIDC_ISSUER_URL    = "https://${local.endpoints.authelia.ingress}"
    STUMP_OIDC_CLIENT_ID     = local.authelia_oidc_clients.stump.client_id
    STUMP_OIDC_CLIENT_SECRET = local.authelia_oidc_clients.stump.client_secret
    STUMP_OIDC_SCOPES        = join(",", local.authelia_oidc_clients.stump.scopes)
  }
  ingress_hostname = local.endpoints.stump.ingress
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
  minio_endpoint    = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_data_bucket = "ebooks"
  minio_bucket      = "stump"
  minio_user        = minio_iam_user.user["stump"]
}

# Navidrome

module "navidrome" {
  source    = "./modules/navidrome"
  name      = local.endpoints.navidrome.name
  namespace = local.endpoints.navidrome.namespace
  images = {
    navidrome  = local.container_images_digest.navidrome
    litestream = local.container_images_digest.litestream
  }
  extra_configs = {
    ND_EXTAUTH_TRUSTEDSOURCES = join(",", [
      local.networks.kubernetes_pod.prefix,
    ])
    ND_ENABLEUSEREDITING  = false
    TZ                    = local.timezone
    ND_EXTAUTH_USERHEADER = "Remote-User"
    ND_SESSIONTIMEOUT     = "24h"
  }
  ingress_hostname = local.endpoints.navidrome.ingress
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
  middleware_ref = {
    name      = "forwardauth-authelia"
    namespace = local.endpoints.traefik.namespace
  }
  minio_endpoint    = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_data_bucket = "music"
  minio_bucket      = "navidrome"
  minio_user        = minio_iam_user.user["navidrome"]
}

# github-actions

module "gha-runner" {
  source               = "./modules/gha_runner"
  name                 = "gha"
  namespace            = "arc-runners"
  controller_namespace = "arc-systems"
  images = {
    gha_runner = local.container_images_digest.gha_runner
  }
  github_credentials = {
    username = var.github_username
    token    = var.github_token
  }
  internal_ca       = data.terraform_remote_state.host.outputs.internal_ca
  registry_endpoint = "${local.endpoints.registry.service}:${local.service_ports.registry}"
  minio_endpoint    = "${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_user        = minio_iam_user.user["arc"]
}

locals {
  flux_service = {

    cloudflare-tunnel = [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "cloudflare-tunnel"
            namespace = "default"
          }
          spec = {
            interval = "15m"
            url      = "https://cloudflare.github.io/helm-charts"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "cloudflare-tunnel"
            namespace = "default"
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "cloudflare-tunnel"
                version = "0.3.2" # renovate: datasource=helm depName=cloudflare-tunnel registryUrl=https://cloudflare.github.io/helm-charts
                sourceRef = {
                  kind = "HelmRepository"
                  name = "cloudflare-tunnel"
                }
                interval = "5m"
              }
            }
            releaseName = "cloudflare-tunnel"
            install = {
              remediation = {
                retries = -1
              }
            }
            upgrade = {
              remediation = {
                retries = -1
              }
            }
            test = {
              enable = false
            }
            values = {
              image = {
                repository = regex(local.container_image_regex, local.container_images.cloudflared).depName
                tag        = regex(local.container_image_regex, local.container_images.cloudflared).tag
              }
              cloudflare = {
                account    = data.terraform_remote_state.sr.outputs.cloudflare_tunnel.account_id
                tunnelName = data.terraform_remote_state.sr.outputs.cloudflare_tunnel.name
                tunnelId   = data.terraform_remote_state.sr.outputs.cloudflare_tunnel.id
                secret     = data.terraform_remote_state.sr.outputs.cloudflare_tunnel.tunnel_secret
                ingress = [
                  for _, e in local.endpoints :
                  {
                    hostname = e.ingress
                    service  = "https://${local.endpoints.traefik.service}"
                  } if lookup(e, "tunnel", false)
                ]
              }
              resources = {
                requests = {
                  memory = "128Mi"
                }
              }
              affinity = {
                nodeAffinity = {
                  preferredDuringSchedulingIgnoredDuringExecution = [
                    {
                      weight = 100
                      preference = {
                        matchExpressions = [
                          {
                            key      = "beta.amd.com/gpu.cu-count"
                            operator = "Lt"
                            values = [
                              "16",
                            ]
                          },
                        ]
                      }
                    },
                  ]
                }
              }
            }
          }
        },
      ] :
      yamlencode(m)
    ]

    gha-runner      = module.gha-runner.manifests
    llama-cpp       = module.llama-cpp.manifests
    llama-cpp-s     = module.llama-cpp-s.manifests
    camofox-browser = module.camofox-browser.manifests
    searxng         = module.searxng.manifests
    kubernetes-mcp  = module.kubernetes-mcp.manifests
    hermes-agent    = module.hermes-agent.manifests
    hostapd         = concat(module.hostapd.manifests, module.qrcode-hostapd.manifests)
    lldap           = module.lldap.manifests
    authelia        = concat(module.authelia-valkey.manifests, module.authelia.manifests)
    stump           = module.stump.manifests
    # open-webui      = module.open-webui.manifests
    # navidrome       = module.navidrome.manifests
  }
}