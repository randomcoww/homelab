# llama-cpp

module "llama-cpp" {
  source    = "./modules/llama_cpp"
  name      = local.endpoints.llama_cpp.name
  namespace = local.endpoints.llama_cpp.namespace
  release   = "0.1.0"
  images = {
    llama_cpp  = local.container_images.llama_cpp
    mountpoint = local.container_images.mountpoint
  }
  ingress_hostname = local.endpoints.llama_cpp.ingress
  llama_swap_config = {
    healthCheckTimeout = 1200
    models = {
      # https://github.com/ggml-org/llama.cpp/discussions/15396
      # https://docs.unsloth.ai/basics/gpt-oss-how-to-run-and-fine-tune#recommended-settings
      "gpt-oss-120b-mxfp4" = {
        cmd = <<-EOF
        /app/llama-server \
          --port $${PORT} \
          --model /llama-cpp/models/gpt-oss-120b-mxfp4-00001-of-00003.gguf \
          --ctx-size 0 \
          --ubatch-size 2048 \
          --batch-size 2048 \
          --jinja \
          --temp 1.0 \
          --top_p 1.0 \
          --top_k 0
        EOF
      }
      "Qwen3-Embedding-0.6B-Q8_0" = {
        cmd = <<-EOF
        /app/llama-server \
          --port $${PORT} \
          --model /llama-cpp/models/Qwen3-Embedding-0.6B-Q8_0.gguf \
          --ctx-size 0 \
          --embedding \
          --pooling last \
          --ubatch-size 8192 \
          --batch-size 8192 \
          --log-disable
        EOF
      }
      "jina-reranker-v3-Q8_0" = {
        cmd = <<-EOF
        /app/llama-server \
          --port $${PORT} \
          --model /llama-cpp/models/jina-reranker-v3-Q8_0.gguf \
          --ctx-size 0 \
          --embedding \
          --reranking \
          --ubatch-size 8192 \
          --batch-size 8192 \
          --log-disable
        EOF
      }
    }
    groups = {
      owui-concurrent = {
        swap = false
        members = [
          "Qwen3-Embedding-0.6B-Q8_0",
          "jina-reranker-v3-Q8_0",
          "gpt-oss-120b-mxfp4",
        ]
      }
    }
    hooks = {
      on_startup = {
        preload = [
          "Qwen3-Embedding-0.6B-Q8_0",
          "jina-reranker-v3-Q8_0",
          "gpt-oss-120b-mxfp4",
        ]
      }
    }
  }
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
                  "96G",
                ]
              },
            ]
          },
        ]
      }
    }
  }
  minio_endpoint      = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_data_bucket   = "models"
  minio_access_secret = local.minio_users.llama_cpp.secret
  ingress_class_name  = local.endpoints.ingress_nginx.name
  nginx_ingress_annotations = merge(local.nginx_ingress_annotations_common, {
    "cert-manager.io/cluster-issuer" = local.kubernetes.cert_issuers.acme_prod
  })
}

# SearXNG

module "searxng" {
  source    = "./modules/searxng"
  name      = local.endpoints.searxng.name
  namespace = local.endpoints.searxng.namespace
  release   = "0.1.0"
  replicas  = 2
  images = {
    searxng = local.container_images.searxng
    valkey  = local.container_images.valkey
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
  ingress_hostname   = local.endpoints.searxng.ingress
  ingress_class_name = local.endpoints.ingress_nginx_internal.name
  nginx_ingress_annotations = merge(local.nginx_ingress_annotations_common, {
    "cert-manager.io/cluster-issuer" = local.kubernetes.cert_issuers.ca_internal
  })
}

module "prometheus-mcp" {
  source    = "./modules/prometheus_mcp"
  name      = local.endpoints.prometheus_mcp.name
  namespace = local.endpoints.prometheus_mcp.namespace
  release   = "0.1.0"
  images = {
    prometheus_mcp  = local.container_images.prometheus_mcp
    mcp_oauth_proxy = local.container_images.mcp_oauth_proxy
    litestream      = local.container_images.litestream
  }
  prometheus_url = "https://${local.endpoints.prometheus.ingress}"
  extra_oauth_configs = {
    OIDC_CONFIGURATION_URL = "https://${local.endpoints.authelia.ingress}/.well-known/openid-configuration"
    OIDC_CLIENT_ID         = random_string.authelia-oidc-client-id["prometheus-mcp"].result
    OIDC_CLIENT_SECRET     = random_password.authelia-oidc-client-secret["prometheus-mcp"].result
    OIDC_PROVIDER_NAME     = "Authelia"
    OIDC_SCOPES            = join(",", local.authelia_oidc_clients.prometheus-mcp.scopes)
  }

  ingress_hostname   = local.endpoints.prometheus_mcp.ingress
  ingress_class_name = local.endpoints.ingress_nginx.name
  nginx_ingress_annotations = merge(local.nginx_ingress_annotations_common, {
    "cert-manager.io/cluster-issuer" = local.kubernetes.cert_issuers.acme_prod
  })

  minio_endpoint      = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket        = "prometheus-mcp"
  minio_access_secret = local.minio_users.prometheus_mcp.secret
}

module "kubernetes-mcp" {
  source    = "./modules/kubernetes_mcp"
  name      = local.endpoints.kubernetes_mcp.name
  namespace = local.endpoints.kubernetes_mcp.namespace
  release   = "0.1.0"
  images = {
    kubernetes_mcp  = local.container_images.kubernetes_mcp
    mcp_oauth_proxy = local.container_images.mcp_oauth_proxy
    litestream      = local.container_images.litestream
  }
  extra_oauth_configs = {
    OIDC_CONFIGURATION_URL = "https://${local.endpoints.authelia.ingress}/.well-known/openid-configuration"
    OIDC_CLIENT_ID         = random_string.authelia-oidc-client-id["kubernetes-mcp"].result
    OIDC_CLIENT_SECRET     = random_password.authelia-oidc-client-secret["kubernetes-mcp"].result
    OIDC_PROVIDER_NAME     = "Authelia"
    OIDC_SCOPES            = join(",", local.authelia_oidc_clients.kubernetes-mcp.scopes)
  }

  ingress_hostname   = local.endpoints.kubernetes_mcp.ingress
  ingress_class_name = local.endpoints.ingress_nginx.name
  nginx_ingress_annotations = merge(local.nginx_ingress_annotations_common, {
    "cert-manager.io/cluster-issuer" = local.kubernetes.cert_issuers.acme_prod
  })

  minio_endpoint      = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket        = "kubernetes-mcp"
  minio_access_secret = local.minio_users.kubernetes_mcp.secret
}

# Open WebUI

module "open-webui" {
  source    = "./modules/open_webui"
  name      = local.endpoints.open_webui.name
  namespace = local.endpoints.open_webui.namespace
  release   = "0.1.0"
  images = {
    open_webui = local.container_images.open_webui
    playwright = local.container_images.playwright
    litestream = local.container_images.litestream
  }
  ingress_hostname = local.endpoints.open_webui.ingress
  extra_configs = {
    WEBUI_URL                      = "https://${local.endpoints.open_webui.ingress}"
    ENABLE_VERSION_UPDATE_CHECK    = false
    ENABLE_OPENAI_API              = true
    OPENAI_API_BASE_URL            = "https://${local.endpoints.llama_cpp.ingress}/v1"
    DEFAULT_MODELS                 = "gpt-oss-120b-mxfp4"
    ENABLE_WEB_SEARCH              = true
    WEB_SEARCH_ENGINE              = "searxng"
    WEB_SEARCH_RESULT_COUNT        = 10
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
    RAG_TOP_K                      = 5
    RAG_EMBEDDING_ENGINE           = "openai"
    RAG_OPENAI_API_BASE_URL        = "https://${local.endpoints.llama_cpp.ingress}/v1"
    RAG_EMBEDDING_MODEL            = "Qwen3-Embedding-0.6B-Q8_0"
    RAG_TOP_K_RERANKER             = 5
    RAG_RERANKING_ENGINE           = "external"
    RAG_EXTERNAL_RERANKER_URL      = "https://${local.endpoints.llama_cpp.ingress}/v1/rerank"
    RAG_RERANKING_MODEL            = "jina-reranker-v3-Q8_0"
    # https://github.com/varunvasudeva1/llm-server-docs?tab=readme-ov-file#mcp-proxy-server
    # https://github.com/open-webui/docs/issues/609
    # https://github.com/javydekoning/homelab/blob/main/k8s/ai-platform/openwebui/TOOL_SERVER_CONNECTIONS.json
    TOOL_SERVER_CONNECTIONS = jsonencode([
      {
        type      = "mcp"
        url       = "https://${local.endpoints.prometheus_mcp.ingress}/mcp"
        auth_type = "oauth_2.1"
        config = {
          enable = true
        }
        spec_type = "url"
        spec      = ""
        path      = ""
        key       = ""
        info = {
          id          = "prometheus-metrics"
          name        = "prometheus-metrics"
          description = "Query service and node metrics and trends"
        }
      },
      {
        type      = "mcp"
        url       = "https://${local.endpoints.kubernetes_mcp.ingress}/mcp"
        auth_type = "oauth_2.1"
        config = {
          enable = true
        }
        spec_type = "url"
        spec      = ""
        path      = ""
        key       = ""
        info = {
          id          = "kubernetes"
          name        = "kubernetes"
          description = "Query Kubernetes resources and logs"
        }
      },
    ])
    # OIDC
    ENABLE_PERSISTENT_CONFIG       = false # persist mcp oauth registration
    ENABLE_SIGNUP                  = false
    ENABLE_LOGIN_FORM              = false
    ENABLE_OAUTH_SIGNUP            = false
    ENABLE_OAUTH_PERSISTENT_CONFIG = false
    ENABLE_OAUTH_ID_TOKEN_COOKIE   = false
    OAUTH_MERGE_ACCOUNTS_BY_EMAIL  = true
    OAUTH_CLIENT_ID                = random_string.authelia-oidc-client-id["open-webui"].result
    OAUTH_CLIENT_SECRET            = random_password.authelia-oidc-client-secret["open-webui"].result
    OPENID_PROVIDER_URL            = "https://${local.endpoints.authelia.ingress}/.well-known/openid-configuration"
    OAUTH_PROVIDER_NAME            = "Authelia"
    OAUTH_SCOPES                   = join(" ", local.authelia_oidc_clients.open-webui.scopes)
    ENABLE_OAUTH_ROLE_MANAGEMENT   = true
    OAUTH_ALLOWED_ROLES            = "openwebui,openwebui-admin"
    OAUTH_ADMIN_ROLES              = "openwebui-admin"
    OAUTH_ROLES_CLAIM              = "groups"
  }
  ingress_class_name = local.endpoints.ingress_nginx.name
  nginx_ingress_annotations = merge(local.nginx_ingress_annotations_common, {
    "cert-manager.io/cluster-issuer" = local.kubernetes.cert_issuers.acme_prod
  })

  minio_endpoint      = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket        = "open-webui"
  minio_access_secret = local.minio_users.open_webui.secret
}