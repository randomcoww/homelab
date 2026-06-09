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
        "http://${local.endpoints.stump.ingress}/api/v2/auth/oidc/callback",
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
    lldap      = local.container_images_digest.lldap
    litestream = local.container_images_digest.litestream
  }
  ports = {
    ldaps = local.service_ports.ldaps
  }
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

  minio_endpoint = "${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket   = "lldap"
  minio_user     = minio_iam_user.user["lldap"]

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
  ports = {
    sentinel = local.service_ports.redis_sentinel
  }
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
    litestream = local.container_images_digest.litestream
  }
  ports = {
    metrics = local.service_ports.metrics
  }
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
  minio_endpoint       = "${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket         = "authelia"
  minio_user           = minio_iam_user.user["authelia"]

  ingress_hostname = local.endpoints.authelia.ingress
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }

  affinity = {
    podAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = [
        {
          labelSelector = {
            matchExpressions = [
              {
                key      = "app"
                operator = "In"
                values = [
                  local.endpoints.lldap.name,
                ]
              },
            ]
          }
          topologyKey = "kubernetes.io/hostname"
          namespaces = [
            local.endpoints.lldap.namespace,
          ]
        },
      ]
    }
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
      jina-embeddings-v5          = "v5-small-text-matching-Q8_0.gguf" # jina-embeddings-v5
      jina-reranker-v3            = "jina-reranker-v3-Q8_0.gguf"
      nemotron-3-super            = "NVIDIA-Nemotron-3-Super-120B-A12B-MXFP4_MOE-00001-of-00003.gguf"
      nemotron-3-nano-omni        = "NVIDIA-Nemotron-3-Nano-Omni-30B-A3B-Reasoning-UD-Q8_K_XL.gguf"
      nemotron-3-nano-omni-mmproj = "mmproj-F16.gguf"
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
      "nemotron-3-super" = {
        cmd = <<-EOF
        $${default_cmd} \
          --model $${nemotron-3-super} \
          --ctx-size 1048576 \
          --jinja \
          --cache-type-k q8_0 \
          --cache-type-v q8_0
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
      "nemotron-3-nano-omni" = {
        cmd = <<-EOF
        $${default_cmd} \
          --model $${nemotron-3-nano-omni} \
          --ctx-size 262144 \
          --jinja \
          --cache-type-k q8_0 \
          --cache-type-v q8_0 \
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
      "jina-embeddings-v5" = {
        cmd = <<-EOF
        $${default_cmd} \
          --model $${jina-embeddings-v5} \
          --ctx-size 0 \
          --batch-size 2048 \
          --ubatch-size 2048 \
          --embedding \
          --pooling last
        EOF
      }
      "jina-reranker-v3" = {
        cmd = <<-EOF
        $${default_cmd} \
          --model $${jina-reranker-v3} \
          --ctx-size 0 \
          --batch-size 2048 \
          --ubatch-size 2048 \
          --reranking
        EOF
      }
    }
    groups = {
      owui-concurrent = {
        swap      = false
        exclusive = true
        members = [
          "nemotron-3-super",
          "jina-embeddings-v5",
          "jina-reranker-v3",
        ]
      }
    }
    hooks = {
      on_startup = {
        preload = [
          "nemotron-3-super",
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
                key      = "amd.com/gpu.vram"
                operator = "In"
                values = [
                  "128G",
                ]
              },
            ]
          },
        ]
      }
    }
  }
  ingress_hostname = local.endpoints.llama_cpp.ingress
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
  }
  ingress_hostname = local.endpoints.camofox_browser.ingress
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
}

resource "random_password" "mcp-auth-token" {
  length           = 32
  override_special = "-_"
}

module "mcp-proxy" {
  source    = "./modules/mcp_proxy"
  name      = local.endpoints.mcp_proxy.name
  namespace = local.endpoints.mcp_proxy.namespace
  images = {
    mcp_proxy      = local.container_images_digest.mcp_proxy
    prometheus_mcp = local.container_images_digest.prometheus_mcp
    kubernetes_mcp = local.container_images_digest.kubernetes_mcp
    searxng_mcp    = local.container_images_digest.searxng_mcp
    camofox_mcp    = local.container_images_digest.camofox_mcp
  }
  replicas            = 1
  searxng_endpoint    = local.endpoints.searxng.ingress
  prometheus_endpoint = local.endpoints.prometheus.ingress
  camofox_endpoint    = local.endpoints.camofox_browser.ingress

  ingress_hostname = local.endpoints.mcp_proxy.ingress
  auth_token       = random_password.mcp-auth-token.result
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
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
    mountpoint   = local.container_images_digest.mountpoint
    litestream   = local.container_images_digest.litestream
  }
  extra_configs = {
    stt_enabled = false
    model = {
      default        = "nemotron-3-super:low"
      provider       = "custom"
      base_url       = "https://${local.endpoints.llama_cpp.ingress}/v1"
      api_key        = random_password.llama-cpp-auth-token.result
      context_length = 1048576
    }
    web = {
      backend     = "searxng"
      searxng_url = "https://${local.endpoints.searxng.ingress}"
    }
    browser = {
      camofox_url = "https://${local.endpoints.camofox_browser.ingress}"
    }
    mcp_servers = merge({
      for name, m in [
        # "kubernetes",
        "prometheus",
      ] :
      name => {
        url = "https://${local.endpoints.mcp_proxy.ingress}/${m}/mcp"
        headers = {
          Authorization : "Bearer ${random_password.mcp-auth-token.result}"
        }
      }
      }, {
      # "github" = {
      #   url = "https://api.githubcopilot.com/mcp"
      #   headers = {
      #     Authorization: "Bearer ${var.github_token}"
      #   }
      # }
    })
    platforms = {
      slack = {
        reply_to_mode = "first"
        extra = {
          reply_in_thread = false
          reply_broadcast = true
        }
      }
    }
    slack = {
      require_mention = true
      strict_mention  = true
    }
  }
  extra_envs = {
    SEARXNG_URL             = "https://${local.endpoints.searxng.ingress}"
    CAMOFOX_URL             = "https://${local.endpoints.camofox_browser.ingress}"
    API_SERVER_ENABLED      = true
    API_SERVER_MODEL_NAME   = local.endpoints.hermes_agent.name
    API_SERVER_KEY          = random_password.hermes-agent-auth-token.result
    GATEWAY_ALLOW_ALL_USERS = true
    SLACK_BOT_TOKEN         = var.slack_bot_token
    SLACK_APP_TOKEN         = var.slack_app_token
    SLACK_ALLOWED_USERS     = var.slack_allowed_users
    SLACK_HOME_CHANNEL      = var.slack_home_channel
    SLACK_HOME_CHANNEL_NAME = "bot"
  }
  # Sample from https://hermes-agent.nousresearch.com/docs/user-guide/features/personality
  soul = <<-EOF
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
  EOF

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
    AUDIO_STT_MODEL                = "nemotron-3-nano-omni:low" # TODO: wait for https://github.com/ggml-org/llama.cpp/pull/22520
    AUDIO_STT_OPENAI_API_BASE_URL  = "https://${local.endpoints.llama_cpp.ingress}/v1"
    AUDIO_STT_OPENAI_API_KEY       = random_password.llama-cpp-auth-token.result
    RAG_TOP_K                      = 5
    RAG_EMBEDDING_ENGINE           = "openai"
    RAG_OPENAI_API_BASE_URL        = "https://${local.endpoints.llama_cpp.ingress}/v1/embeddings"
    RAG_OPENAI_API_KEY             = random_password.llama-cpp-auth-token.result
    RAG_EMBEDDING_MODEL            = "jina-embeddings-v5"
    RAG_TOP_K_RERANKER             = 5
    RAG_RERANKING_ENGINE           = "external"
    RAG_EXTERNAL_RERANKER_URL      = "https://${local.endpoints.llama_cpp.ingress}/v1/rerank"
    RAG_EXTERNAL_RERANKER_API_KEY  = random_password.llama-cpp-auth-token.result
    RAG_RERANKING_MODEL            = "jina-reranker-v3"
    TOOL_SERVER_CONNECTIONS = jsonencode(concat([
      for _, m in [
        "kubernetes",
        "searxng",
        "camofox",
        "prometheus",
      ] :
      {
        type      = "mcp"
        url       = "https://${local.endpoints.mcp_proxy.ingress}/${m}/mcp"
        auth_type = "bearer"
        config = {
          enable                    = true
          function_name_filter_list = ""
        }
        spec_type = "url"
        spec      = ""
        path      = ""
        key       = random_password.mcp-auth-token.result
        info = {
          id   = m
          name = m
        }
      }
      ], [
      # {
      #   type      = "mcp"
      #   url       = "https://api.githubcopilot.com/mcp"
      #   auth_type = "bearer"
      #   config = {
      #     enable                    = true
      #     function_name_filter_list = ""
      #   }
      #   spec_type = "url"
      #   spec      = ""
      #   path      = ""
      #   key       = var.github_token
      #   info = {
      #     id          = "github"
      #     name        = "github"
      #     description = "Query GitHub resources"
      #   }
      # },
    ]))
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
    mountpoint = local.container_images_digest.mountpoint
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

module "sunshine-desktop" {
  source    = "./modules/sunshine_desktop"
  name      = local.endpoints.sunshine_desktop.name
  namespace = local.endpoints.sunshine_desktop.namespace
  images = {
    sunshine_desktop = local.container_images_digest.sunshine_desktop
    nginx            = local.container_images_digest.nginx
  }
  user               = "sunshine"
  uid                = 10000
  storage_class_name = "local-path"
  extra_configs = [
    {
      path    = "/etc/xdg/foot/foot.ini"
      content = <<-EOF
      font=monospace:size=14
      EOF
    },
    {
      path    = "/etc/tmux.conf"
      content = <<-EOF
      set -g history-limit 10000
      set -g mouse on
      set-option -s set-clipboard off
      bind-key -T copy-mode MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -in -sel clip"
      EOF
    },
    {
      path    = "/etc/profile.d/tmux.sh"
      content = <<-EOF
      if [ -z "$TMUX" ]; then
        exec tmux new-session -A -s default
      fi
      EOF
    },
    {
      path    = "/etc/sway/config.d/sync"
      content = <<-EOF
      output * bg #000000 solid_color
      output * allow_tearing yes
      output * max_render_time off
      EOF
    },
  ]
  extra_envs = [
    {
      name  = "TZ"
      value = local.timezone
    },
    # TODO: track https://github.com/LizardByte/Sunshine/issues/4050
    # {
    #   name  = "WLR_RENDERER"
    #   value = "vulkan"
    # },
    {
      name  = "PROTON_ENABLE_WAYLAND"
      value = 1
    },
    {
      name  = "PROTON_ENABLE_HDR"
      value = 1
    },
    {
      name  = "PROTON_USE_NTSYNC"
      value = 1
    },
    {
      name  = "PROTON_FSR4_UPGRADE"
      value = 1
    },
    {
      name  = "PROTON_NO_WM_DECORATION"
      value = 1
    },
    {
      name  = "PROTON_LOCAL_SHADER_CACHE"
      value = 1
    },
    {
      name  = "AMD_VULKAN_ICD"
      value = "RADV"
    },
    {
      name  = "MESA_SHADER_CACHE_MAX_SIZE"
      value = "12G"
    },
    {
      name  = "AMD_USERQ"
      value = 1
    },
    {
      name  = "ENABLE_LAYER_MESA_ANTI_LAG"
      value = 1
    },
  ]
  affinity = {
    nodeAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = {
        nodeSelectorTerms = [
          {
            matchExpressions = [
              {
                key      = "amd.com/gpu.cu-count"
                operator = "Gt"
                values = [
                  "31",
                ]
              },
            ]
          },
        ]
      }
    }
  }
  security_context = {
    # TODO: Privileged to make libinput work https://github.com/squat/generic-device-plugin/issues/148
    privileged = true
    # capabilities = {
    #   add = [
    #     "ALL",
    #   ]
    # }
  }
  service_ip       = local.services.sunshine_desktop.ip
  service_hostname = local.endpoints.sunshine_desktop.service
  ingress_hostname = local.endpoints.sunshine_desktop.ingress
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
  middleware_ref = {
    name      = "forwardauth-authelia"
    namespace = local.endpoints.traefik.namespace
  }
}

# Navidrome

module "navidrome" {
  source    = "./modules/navidrome"
  name      = local.endpoints.navidrome.name
  namespace = local.endpoints.navidrome.namespace
  images = {
    navidrome  = local.container_images_digest.navidrome
    mountpoint = local.container_images_digest.mountpoint
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
                limits = {
                  memory = "128Mi"
                }
              }
            }
          }
        },
      ] :
      yamlencode(m)
    ]

    lldap            = module.lldap.manifests
    authelia         = concat(module.authelia-valkey.manifests, module.authelia.manifests)
    llama-cpp        = module.llama-cpp.manifests
    sunshine-desktop = module.sunshine-desktop.manifests
    camofox-browser  = module.camofox-browser.manifests
    searxng          = module.searxng.manifests
    hermes-agent     = module.hermes-agent.manifests
    open-webui       = module.open-webui.manifests
    hostapd          = concat(module.hostapd.manifests, module.qrcode-hostapd.manifests)
    stump            = module.stump.manifests
    gha-runner       = module.gha-runner.manifests
    navidrome        = module.navidrome.manifests
    mcp-proxy        = module.mcp-proxy.manifests
  }
}