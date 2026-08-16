resource "random_password" "llama-cpp-auth-token" {
  length           = 32
  override_special = "-_"
}

module "llama-cpp" {
  source    = "./modules/llama-cpp"
  name      = "llama-cpp"
  namespace = "default"
  images = {
    llama-swap = {
      repository = "reg.cluster.internal/randomcoww/llama-swap-ffmpeg"
      tag        = "unified-vulkan-2026-08-11.1786430449@sha256:9c840619d839d201a6bec1efee745c83cd54326f7f55ee54359ec460110295e0" # renovate: datasource=docker depName=reg.cluster.internal/randomcoww/llama-swap-ffmpeg
    }
  }
  models = merge([
    for _, image in [
      {
        repository = "reg.cluster.internal/randomcoww/qwen3.8-27b-ud-q8-k-xl"
        tag        = "v1786728652@sha256:76c5cbf6ac40d6b5edf9c1e9cb9f35c12810e743b34011d27e8757b18963af77" # renovate: datasource=docker depName=reg.cluster.internal/randomcoww/qwen3.8-27b-ud-q8-k-xl
        files = {
          qwen-3-8-27b        = "Qwen3.8-27B-UD-Q8_K_XL.gguf"
          qwen-3-8-27b-mmproj = "mmproj-BF16.gguf"
        }
      },
      {
        repository = "reg.cluster.internal/randomcoww/muse-glimmer-30b-ud-q8-k-xl"
        tag        = "v1786426571@sha256:88acda0846a6bac50ab95556fd925ea26e7cd9ed85f8039360a1b35915235a66" # renovate: datasource=docker depName=reg.cluster.internal/randomcoww/muse-glimmer-30b-ud-q8-k-xl
        files = {
          muse-glimmer-30b        = "Muse-Glimmer-30B-UD-Q8_K_XL.gguf"
          muse-glimmer-30b-mmproj = "mmproj-Muse-Glimmer-30B-BF16.gguf"
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
      qwen-3-8-27b = {
        cmd = <<-EOF
        $${default_cmd} \
          --model $${qwen-3-8-27b} \
          --ctx-size 262144 \
          --jinja \
          --top-p 0.95 \
          --top-k 20 \
          --min-p 0.0 \
          --presence-penalty 0.0 \
          --repeat-penalty 1.0 \
          --spec-type draft-mtp \
          --spec-draft-n-max 3 \
          --reasoning-preserve \
          --no-context-shift \
          --image-min-tokens 2048 \
          --mmproj $${qwen-3-8-27b-mmproj}
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
      muse-glimmer-30b = {
        cmd = <<-EOF
        $${default_cmd} \
          --model $${muse-glimmer-30b} \
          --ctx-size 262144 \
          --jinja \
          --top-p 0.95 \
          --top-k 64 \
          --mmproj $${muse-glimmer-30b-mmproj} \
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
      persist = {
        swap       = false
        exclusive  = false
        persistent = true
        members = [
          "whisper-large-v3-turbo",
        ]
      }
    }
    hooks = {
      on_startup = {
        preload = [
          "whisper-large-v3-turbo",
          "qwen-3-8-27b",
        ]
      }
    }
  }
  extra_envs = {
    "ROCBLAS_USE_HIPBLASLT" = 1
    "AMD_VULKAN_ICD"        = "RADV"
    "RADV_PERFTEST"         = "sam"
  }
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
  ingress_hostname = local.endpoints.llama-cpp.hostname
  gateway_ref = {
    name      = local.services.cilium.name
    namespace = local.services.cilium.namespace
  }
  resources = {
    requests = {
      memory = "64Gi"
    }
  }
  gpu_resource_claim = local.resource_claims.amd-gpu-gfx1151
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
    base_url = "https://${local.endpoints.llama-cpp.hostname}/v1"
    api_key  = random_password.llama-cpp-auth-token.result
  }
  sensitive = true
}