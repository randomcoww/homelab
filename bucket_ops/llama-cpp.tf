locals {
  llama-cpp_name      = "llama-cpp"
  llama-cpp_namespace = "default"
  llama-cpp_port      = 8080
}

resource "random_password" "llama-cpp-auth-token" {
  length           = 32
  override_special = "-_"
}

module "llama-cpp" {
  source    = "./modules/llama-cpp"
  name      = local.llama-cpp_name
  namespace = local.llama-cpp_namespace
  images = {
    llama-swap = {
      repository = "reg.cluster.internal/randomcoww/llama-swap-ffmpeg"
      tag        = "unified-vulkan-2026-08-03.1785766351@sha256:1361addc3e4b553fef5d20b7815bef75b92a4b6199913175c06343090e98958c" # renovate: datasource=docker depName=reg.cluster.internal/randomcoww/llama-swap-ffmpeg
    }
  }
  models = merge([
    for _, image in [
      {
        repository = "reg.cluster.internal/randomcoww/qwen3.6-27b-bf16"
        tag        = "v1783465086@sha256:48415dda9b84ae3de638c7e218d69e1feb56db51b966cf65eac18f9fafad7486" # renovate: datasource=docker depName=reg.cluster.internal/randomcoww/qwen3.6-27b-bf16
        files = {
          qwen-3-6-27b        = "Qwen3.6-27B-BF16-00001-of-00002.gguf"
          qwen-3-6-27b-mmproj = "Qwen3.6-27B-mmproj-BF16.gguf"
        }
      },
      {
        repository = "reg.cluster.internal/randomcoww/gemma-4-31b-it-bf16"
        tag        = "v1783493322@sha256:0df8bc92746e34aefffc89708257c576743abc2577d4454d176e9af044a54e60" # renovate: datasource=docker depName=reg.cluster.internal/randomcoww/gemma-4-31b-it-bf16
        files = {
          gemma-4-31b        = "gemma-4-31B-it-BF16-00001-of-00002.gguf"
          gemma-4-31b-mtp    = "gemma-4-31B-it-BF16-MTP.gguf"
          gemma-4-31b-mmproj = "gemma-4-31B-it-mmproj-BF16.gguf"
        }
      },
      {
        repository = "reg.cluster.internal/randomcoww/whisper-large-v3-turbo-q8-0"
        tag        = "v1781645858@sha256:b6ddc70ec2752d59bbaaa936ec2ae6e4ee1e5a5ced5fb4cd8d77e4a272585039" # renovate: datasource=docker depName=reg.cluster.internal/randomcoww/whisper-large-v3-turbo-q8-0
        files = {
          whisper-large-v3-turbo = "ggml-large-v3-turbo-q8_0.bin"
        }
      },
      ] : {
      for key, file in image.files :
      key => {
        image = "${image.repository}:${image.tag}"
        file  = file
      }
    }
  ]...)
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
    }
    groups = {
      agent-concurrent = {
        swap      = false
        exclusive = true
        members = [
          "qwen-3-6-27b",
          "whisper-large-v3-turbo",
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
  service_port = local.llama-cpp_port
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
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}

# outputs

output "llama-cpp" {
  value = {
    api_key = random_password.llama-cpp-auth-token.result
  }
  sensitive = true
}