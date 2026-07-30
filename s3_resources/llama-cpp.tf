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
    name      = local.endpoints.cilium.name
    namespace = local.endpoints.cilium.namespace
  }
}

resource "minio_s3_object" "fluxcd-llama-cpp" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.llama-cpp.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "llama-cpp/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.bucket["fluxcd"],
  ]
}

# outputs

output "llama-cpp" {
  value = {
    base_url = "https://${local.endpoints.llama_cpp.ingress}/v1"
    api_key  = random_password.llama-cpp-auth-token.result
  }
  sensitive = true
}