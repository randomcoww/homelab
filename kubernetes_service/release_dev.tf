# llama-cpp

resource "random_password" "llama-cpp-auth-token" {
  length           = 32
  override_special = "-_"
}

module "llama-cpp" {
  source    = "./modules/llama_cpp"
  name      = local.endpoints.llama_cpp.name
  namespace = local.endpoints.llama_cpp.namespace
  release   = "0.1.0"
  images = {
    llama_swap = local.container_images_digest.llama_cpp_vulkan
  }
  models = {
    for _, k in [
      "gpt-oss-120b-F16",
      "Qwen3-Embedding-0.6B-Q8_0",
      "jina-reranker-v3-Q8_0",
      "GLM-4.7-Flash-Q8_0",
    ] :
    k => local.container_images_digest[k]
  }
  api_keys = [
    random_password.llama-cpp-auth-token.result,
  ]
  llama_swap_config = {
    healthCheckTimeout = 300
    models = {
      # https://github.com/ggml-org/llama.cpp/discussions/15396
      # https://docs.unsloth.ai/basics/gpt-oss-how-to-run-and-fine-tune#recommended-settings
      "gpt-oss-120b-F16" = {
        cmd = <<-EOF
        $${default_cmd} \
          --model $${gpt-oss-120b-f16} \
          --ctx-size 0 \
          --jinja \
          --temp 1.0 \
          --top_p 1.0 \
          --top_k 0.0
        EOF
      }
      "Qwen3-Embedding-0.6B-Q8_0" = {
        cmd = <<-EOF
        $${default_cmd} \
          --model $${qwen3-embedding-0-6b-q8-0} \
          --ctx-size 0 \
          --ubatch-size 2048 \
          --batch-size 2048 \
          --embedding \
          --pooling last
        EOF
      }
      "jina-reranker-v3-Q8_0" = {
        cmd = <<-EOF
        $${default_cmd} \
          --model $${jina-reranker-v3-q8-0} \
          --ctx-size 0 \
          --ubatch-size 2048 \
          --batch-size 2048 \
          --embedding \
          --reranking
        EOF
      }
      # https://unsloth.ai/docs/models/glm-4.7-flash
      "GLM-4.7-Flash-Q8_0" = {
        cmd = <<-EOF
        $${default_cmd} \
          --model $${glm-4-7-flash-q8-0} \
          --ctx-size 0 \
          --jinja \
          --temp 1.0 \
          --top-p 0.95 \
          --min-p 0.01 \
          --repeat-penalty 1.0
        EOF
      }
    }
    groups = {
      owui-concurrent = {
        swap      = false
        exclusive = true
        members = [
          "gpt-oss-120b-F16",
          "Qwen3-Embedding-0.6B-Q8_0",
          "jina-reranker-v3-Q8_0",
        ]
      }
      code-concurrent = {
        swap      = false
        exclusive = true
        members = [
          "GLM-4.7-Flash-Q8_0",
        ]
      }
    }
    hooks = {
      on_startup = {
        preload = [
          "gpt-oss-120b-F16",
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

# SearXNG

module "searxng" {
  source    = "./modules/searxng"
  name      = local.endpoints.searxng.name
  namespace = local.endpoints.searxng.namespace
  release   = "0.1.0"
  replicas  = 2
  images = {
    searxng = local.container_images_digest.searxng
    valkey  = local.container_images_digest.valkey
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

# Open WebUI

module "open-webui" {
  source    = "./modules/open_webui"
  name      = local.endpoints.open_webui.name
  namespace = local.endpoints.open_webui.namespace
  release   = "0.1.0"
  images = {
    open_webui = local.container_images_digest.open_webui
    litestream = local.container_images_digest.litestream
  }
  extra_configs = {
    WEBUI_URL                      = "https://${local.endpoints.open_webui.ingress}"
    ENABLE_VERSION_UPDATE_CHECK    = false
    ENABLE_OPENAI_API              = true
    OPENAI_API_BASE_URL            = "https://${local.endpoints.llama_cpp.ingress}/v1"
    OPENAI_API_KEY                 = random_password.llama-cpp-auth-token.result
    DEFAULT_MODELS                 = "gpt-oss-120b-F16"
    ENABLE_WEB_SEARCH              = true
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
    RAG_TOP_K                      = 5
    RAG_EMBEDDING_ENGINE           = "openai"
    RAG_OPENAI_API_BASE_URL        = "https://${local.endpoints.llama_cpp.ingress}/v1/embeddings"
    RAG_OPENAI_API_KEY             = random_password.llama-cpp-auth-token.result
    RAG_EMBEDDING_MODEL            = "Qwen3-Embedding-0.6B-Q8_0"
    RAG_TOP_K_RERANKER             = 5
    RAG_RERANKING_ENGINE           = "external"
    RAG_EXTERNAL_RERANKER_URL      = "https://${local.endpoints.llama_cpp.ingress}/v1/rerank"
    RAG_EXTERNAL_RERANKER_API_KEY  = random_password.llama-cpp-auth-token.result
    RAG_RERANKING_MODEL            = "jina-reranker-v3-Q8_0"
    # https://github.com/varunvasudeva1/llm-server-docs?tab=readme-ov-file#mcp-proxy-server
    # https://github.com/open-webui/docs/issues/609
    # https://github.com/javydekoning/homelab/blob/main/k8s/ai-platform/openwebui/TOOL_SERVER_CONNECTIONS.json
    TOOL_SERVER_CONNECTIONS = jsonencode([
      /*
      {
        type      = "mcp"
        url       = "https://${local.endpoints.kubernetes_mcp.ingress}/mcp"
        auth_type = "bearer"
        config = {
          enable                    = true
          function_name_filter_list = ""
        }
        spec_type = "url"
        spec      = ""
        path      = ""
        key       = random_password.kubernetes-mcp-auth-token.result
        info = {
          id          = "kubernetes"
          name        = "kubernetes"
          description = "Query Kubernetes resources and logs"
        }
      },
      */
    ])
    # OIDC
    ENABLE_PERSISTENT_CONFIG       = false # persist mcp oauth registration
    ENABLE_SIGNUP                  = false
    ENABLE_LOGIN_FORM              = false
    ENABLE_OAUTH_SIGNUP            = true
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
  ingress_hostname = local.endpoints.open_webui.ingress
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
  minio_endpoint      = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket        = "open-webui"
  minio_access_secret = local.minio_users.open_webui.secret
}

module "kubernetes-mcp" {
  source    = "./modules/kubernetes_mcp"
  name      = local.endpoints.kubernetes_mcp.name
  namespace = local.endpoints.kubernetes_mcp.namespace
  release   = "0.1.0"
  replicas  = 1
  images = {
    kubernetes_mcp = local.container_images.kubernetes_mcp
    nginx          = local.container_images.nginx
  }
  oauth_client_id         = random_string.authelia-oidc-client-id["kubernetes-mcp"].result
  oauth_authorization_url = "https://${local.endpoints.authelia.ingress}"
  oauth_scopes            = local.authelia_oidc_clients.kubernetes-mcp.scopes
  ingress_hostname        = local.endpoints.kubernetes_mcp.ingress
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
}