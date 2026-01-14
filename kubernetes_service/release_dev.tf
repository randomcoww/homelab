locals {
  mcp_proxies = {
    searxng = {
      command = "npx"
      args = [
        "-y",
        "mcp-searxng",
      ]
      env = {
        SEARXNG_URL = "https://${local.endpoints.searxng.ingress}"
      }
      name        = "web-search"
      description = "Search the web with SearXNG"
    }
  }
}

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
  ingress_class_name  = local.endpoints.ingress_nginx_internal.name
  nginx_ingress_annotations = merge(local.nginx_ingress_annotations_common, {
    "cert-manager.io/cluster-issuer" = local.kubernetes.cert_issuers.ca_internal
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

# MCP

module "mcp-proxy" {
  source    = "./modules/mcp_proxy"
  name      = local.endpoints.mcp_proxy.name
  namespace = local.endpoints.mcp_proxy.namespace
  release   = "0.1.0"
  replicas  = 2
  images = {
    mcp_proxy = local.container_images.mcp_proxy
  }
  config = {
    mcpProxy = {
      version = "1.0.0"
      type    = "streamable-http"
      options = {
        panicIfInvalid = true
        logEnabled     = true
      }
    },
    mcpServers = {
      for type, config in local.mcp_proxies :
      type => {
        command = config.command
        args    = config.args
        env     = config.env
      }
    }
  }
  ingress_hostname   = local.endpoints.mcp_proxy.ingress
  ingress_class_name = local.endpoints.ingress_nginx_internal.name
  nginx_ingress_annotations = merge(local.nginx_ingress_annotations_common, {
    "cert-manager.io/cluster-issuer" = local.kubernetes.cert_issuers.ca_internal
  })
}

# Open WebUI

module "open-webui" {
  source    = "./modules/open_webui"
  name      = local.endpoints.open_webui.name
  namespace = local.endpoints.open_webui.namespace
  release   = "0.1.0"
  images = {
    open_webui = local.container_images.open_webui
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
    ENABLE_PERSISTENT_CONFIG       = false
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
      for type, config in local.mcp_proxies :
      {
        type      = "mcp"
        url       = "https://${local.endpoints.mcp_proxy.ingress}/${type}/mcp"
        auth_type = "none"
        config = {
          enable = true
        }
        spec_type = "url"
        spec      = ""
        path      = ""
        key       = ""
        info = {
          id          = type
          name        = config.name
          description = config.description
        }
      }
    ])
    # OIDC
    ENABLE_SIGNUP                 = false
    ENABLE_LOGIN_FORM             = false
    ENABLE_OAUTH_SIGNUP           = true
    OAUTH_MERGE_ACCOUNTS_BY_EMAIL = true
    OAUTH_CLIENT_ID               = random_string.authelia-oidc-client-id["open-webui"].result
    OAUTH_CLIENT_SECRET           = random_password.authelia-oidc-client-secret["open-webui"].result
    OPENID_PROVIDER_URL           = "https://${local.endpoints.authelia.ingress}/.well-known/openid-configuration"
    OAUTH_PROVIDER_NAME           = "Authelia"
    OAUTH_SCOPES                  = "openid email profile groups"
    ENABLE_OAUTH_ROLE_MANAGEMENT  = true
    OAUTH_ALLOWED_ROLES           = "openwebui,openwebui-admin"
    OAUTH_ADMIN_ROLES             = "openwebui-admin"
    OAUTH_ROLES_CLAIM             = "groups"
  }
  ingress_class_name = local.endpoints.ingress_nginx.name
  nginx_ingress_annotations = merge(local.nginx_ingress_annotations_common, {
    "cert-manager.io/cluster-issuer" = local.kubernetes.cert_issuers.acme_prod
  })

  minio_endpoint      = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket        = "open-webui"
  minio_access_secret = local.minio_users.open_webui.secret
}

# Internal registry

module "registry" {
  source    = "./modules/registry"
  name      = local.endpoints.registry.name
  namespace = local.endpoints.registry.namespace
  release   = "0.1.0"
  replicas  = 2
  images = {
    registry = local.container_images.registry
  }
  ports = {
    registry = local.service_ports.registry
  }
  ca                      = data.terraform_remote_state.sr.outputs.trust.ca
  loadbalancer_class_name = "kube-vip.io/kube-vip-class"

  minio_endpoint      = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket        = "registry"
  minio_bucket_prefix = "/"
  minio_access_secret = local.minio_users.registry.secret

  service_ip       = local.services.registry.ip
  service_hostname = local.endpoints.registry.service
  nginx_ingress_annotations = merge(local.nginx_ingress_annotations_common, {
    "cert-manager.io/cluster-issuer" = local.kubernetes.cert_issuers.acme_prod
  })
}