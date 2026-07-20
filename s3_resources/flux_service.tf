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
    hermes-dashboard = {
      client_name = "hermes-dashboard"
      scopes = [
        "openid",
        "email",
        "profile",
      ]
      require_pkce          = false
      pkce_challenge_method = ""
      redirect_uris = [
        "https://${local.endpoints.hermes_agent.ingress}/auth/callback",
      ]
      consent_mode = "implicit"
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

resource "random_password" "lldap-user" {
  length  = 30
  special = false
}

resource "random_password" "lldap-password" {
  length  = 30
  special = false
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
  ca_issuer_name   = local.kubernetes.cert_issuers.ca_internal
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
  ca_issuer_name   = local.kubernetes.cert_issuers.ca_internal
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
  ca_issuer_name = local.kubernetes.cert_issuers.ca_internal
  ldap_endpoint  = "${local.endpoints.lldap.service_fqdn}:${local.service_ports.ldaps}"
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
      qwen-3-6-27b                          = "Qwen3.6-27B-BF16-00001-of-00002.gguf"
      qwen-3-6-27b-mmproj                   = "Qwen3.6-27B-mmproj-BF16.gguf"
      gemma-4-31b                           = "gemma-4-31B-it-BF16-00001-of-00002.gguf"
      gemma-4-31b-mtp                       = "gemma-4-31B-it-BF16-MTP.gguf"
      gemma-4-31b-mmproj                    = "gemma-4-31B-it-mmproj-BF16.gguf"
      whisper-large-v3-turbo                = "ggml-large-v3-turbo-q8_0.bin"
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
      qwen-3-6-27b = {
        cmd = <<-EOF
        $${default_cmd} \
          --model $${qwen-3-6-27b} \
          --ctx-size 262144 \
          --jinja \
          --top-p 0.95 \
          --top-k 20 \
          --min-p 0.00 \
          --spec-type draft-mtp \
          --spec-draft-n-max 2 \
          --cache-type-k bf16 \
          --cache-type-v bf16 \
          --mmproj $${qwen-3-6-27b-mmproj}
        EOF
        filters = {
          stripParams = "temperature"
          setParamsByID = {
            "$${MODEL_ID}" = {
              temperature = 1.0
            }
            "$${MODEL_ID}:low" = {
              temperature = 0.6
            }
          }
        }
      }
      gemma-4-31b = {
        cmd = <<-EOF
        $${default_cmd} \
          --model $${gemma-4-31b} \
          --ctx-size 262144 \
          --jinja \
          --top-p 0.95 \
          --top-k 64 \
          --model-draft $${gemma-4-31b-mtp} \
          --spec-type draft-mtp \
          --spec-draft-n-max 4 \
          --cache-type-k bf16 \
          --cache-type-v bf16 \
          --mmproj $${gemma-4-31b-mmproj} \
        EOF
        filters = {
          stripParams = "temperature"
          setParamsByID = {
            "$${MODEL_ID}" = {
              temperature = 1.0
              chat_template_kwargs = {
                enable_thinking = true
              }
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
          "qwen-3-6-27b",
          "whisper-large-v3-turbo",
          "jina-embeddings-v5-omni",
          "jina-reranker-m0",
        ]
      }
    }
    hooks = {
      on_startup = {
        preload = [
          "qwen-3-6-27b",
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

resource "random_password" "camofox-browser-auth-token" {
  length           = 32
  override_special = "-_"
}

module "camofox-browser" {
  source    = "./modules/camofox_browser"
  name      = local.endpoints.camofox_browser.name
  namespace = local.endpoints.camofox_browser.namespace
  images = {
    camofox_browser = local.container_images_digest.camofox_browser
  }
  extra_configs = {
    PROXY_HOST         = regex(local.domain_regex, var.scrape_proxy_server).hostname
    PROXY_PORT         = regex(local.domain_regex, var.scrape_proxy_server).port
    PROXY_USERNAME     = var.scrape_proxy_username
    PROXY_PASSWORD     = var.scrape_proxy_password
    CAMOFOX_ACCESS_KEY = random_password.camofox-browser-auth-token.result
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
  ca_issuer_name   = local.kubernetes.cert_issuers.ca_internal
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
    hermes_webui = local.container_images_digest.hermes_webui
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
        url = "https://${local.endpoints.kubernetes_mcp.service}:${local.service_ports.kubernetes_mcp}/mcp"
        client_cert = [
          "$${INTERNAL_CLIENT_CERT_PATH}",
          "$${INTERNAL_CLIENT_KEY_PATH}",
        ]
        timeout         = 30
        connect_timeout = 30
      }
      github = {
        url = "https://api.githubcopilot.com/mcp"
        headers = {
          Authorization = "Bearer $${GITHUB_TOKEN}"
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
        timeout         = 30
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
    OPENAI_BASE_URL             = "https://${local.endpoints.llama_cpp.ingress}/v1"
    OPENAI_API_KEY              = random_password.llama-cpp-auth-token.result
    SEARXNG_URL                 = "https://${local.endpoints.searxng.ingress}"
    CAMOFOX_URL                 = "https://${local.endpoints.camofox_browser.ingress}"
    CAMOFOX_API_KEY             = random_password.camofox-browser-auth-token.result
    AUXILIARY_VISION_PROVIDER   = "auto"
    HERMES_STREAM_READ_TIMEOUT  = 1800
    HERMES_STREAM_STALE_TIMEOUT = 1800
    HERMES_CRON_TIMEOUT         = 1800
    HERMES_TIMEZONE             = local.timezone
    GITHUB_TOKEN                = var.github_token
    API_SERVER_MODEL_NAME       = local.endpoints.hermes_agent.name
    API_SERVER_KEY              = random_password.hermes-agent-auth-token.result
    GATEWAY_ALLOW_ALL_USERS     = true
    SLACK_BOT_TOKEN             = var.slack_bot_token
    SLACK_APP_TOKEN             = var.slack_app_token
    SLACK_ALLOWED_USERS         = var.slack_allowed_users
    SLACK_HOME_CHANNEL          = var.slack_home_channel
    SLACK_HOME_CHANNEL_NAME     = "bot"
    # TODO: STT config - using groq is a hack that may only work because it expects the same whisper-large-v3-turbo model that I'm using
    GROQ_BASE_URL  = "https://${local.endpoints.llama_cpp.ingress}/v1"
    STT_GROQ_MODEL = "whisper-large-v3-turbo"
    GROQ_API_KEY   = random_password.llama-cpp-auth-token.result
    # mnemosyne vars #
    MNEMOSYNE_HOST_LLM_ENABLED = true
    # custom vars #
    ALPACA_API_KEY    = var.alpaca_api_key
    ALPACA_SECRET_KEY = var.alpaca_secret_key
  }
  extra_agent_envs = {
    "TZ" = local.timezone
  }
  extra_webui_envs = {
    # TODO: enable OIDC after https://github.com/nesquena/hermes-webui/pull/6164
    # HERMES_WEBUI_OIDC_CLIENT_ID               = local.authelia_oidc_clients.hermes-dashboard.client_id
    # HERMES_WEBUI_OIDC_CLIENT_SECRET           = local.authelia_oidc_clients.hermes-dashboard.client_secret
    # HERMES_WEBUI_OIDC_ISSUER                  = "https://${local.endpoints.authelia.ingress}"
    # HERMES_WEBUI_OIDC_ALLOW_CLAIM             = "email"
    # HERMES_WEBUI_OIDC_ALLOW_VALUES            = var.smtp_username
    # HERMES_WEBUI_OIDC_ALLOW_PRIVATE_ENDPOINTS = true
  }
  ca_issuer_name   = local.kubernetes.cert_issuers.ca_internal
  ingress_hostname = local.endpoints.hermes_agent.ingress
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
  minio_endpoint = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket   = "hermes-agent"
  minio_user     = minio_iam_user.user["hermes_agent"]
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
  ca_issuer_name    = local.kubernetes.cert_issuers.ca_internal
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

    tailscale-connector = [
      for _, m in [
        {
          apiVersion = "tailscale.com/v1alpha1"
          kind       = "Connector"
          metadata = {
            name = "ts-${local.kubernetes.cluster_name}"
          }
          spec = {
            replicas       = 2
            hostnamePrefix = "ts-${local.kubernetes.cluster_name}"
            subnetRouter = {
              advertiseRoutes = [
                local.networks[local.services.apiserver.network.name].prefix,
                local.networks.service.prefix,
                local.networks.kubernetes_service.prefix,
              ]
            }
          }
        },
      ] :
      yamlencode(m)
    ]

    gha-runner      = module.gha-runner.manifests
    llama-cpp       = module.llama-cpp.manifests
    camofox-browser = module.camofox-browser.manifests
    searxng         = module.searxng.manifests
    kubernetes-mcp  = module.kubernetes-mcp.manifests
    hermes-agent    = module.hermes-agent.manifests
    hostapd         = concat(module.hostapd.manifests, module.qrcode-hostapd.manifests)
    lldap           = module.lldap.manifests
    authelia        = concat(module.authelia-valkey.manifests, module.authelia.manifests)
    stump           = module.stump.manifests
    navidrome       = module.navidrome.manifests
  }
}