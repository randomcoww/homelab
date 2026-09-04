locals {
  llama-cpp_port      = 8080
  llama-cpp_namespace = "default"
}

module "llama-cpp" {
  source    = "./modules/llama-cpp"
  name      = "llama-cpp"
  namespace = local.llama-cpp_namespace # must be in same namespace as sunshine to share GPU
  images = {
    llama-swap = {
      repository = "zot.cluster.internal/randomcoww/llama-swap-ffmpeg"
      tag        = "unified-vulkan-2026-08-31.1788200486@sha256:873b6873e5e3ddfae3be8642ed54def5dcb1a61043e203d0360893f07a0dc144" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/llama-swap-ffmpeg
    }
  }
  image_volumes = merge([
    for _, image in [
      {
        repository = "zot.cluster.internal/randomcoww/qwen3.8-27b-ud-q8-k-xl"
        tag        = "v1787906227@sha256:65cc79a804b0c6e6b1d386428bb0f675780b44c44a64edab2a481132c962aec7" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/qwen3.8-27b-ud-q8-k-xl
        files = {
          qwen-3-8-27b        = "Qwen3.8-27B-UD-Q8_K_XL.gguf"
          qwen-3-8-27b-mmproj = "mmproj-BF16.gguf"
        }
      },
      {
        repository = "zot.cluster.internal/randomcoww/granite-4.2-3b-q8-0"
        tag        = "v1788247923@sha256:4174ba613c266d09fa2fa4c854e948b28c10d067a7ce71966b56bc88c92059d5" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/granite-4.2-3b-q8-0
        files = {
          granite-4-2-3b = "granite-4.2-3b-Q8_0.gguf"
        }
      },
      {
        repository = "zot.cluster.internal/randomcoww/whisper-large-v3-turbo-q8-0"
        tag        = "v1787900300@sha256:3a5b69ec71b585ac016b190ebcdbae1ac4ac19b3e3f393c31c08c709b851429a" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/whisper-large-v3-turbo-q8-0
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
    random_password.inference-gateway-api-key.result,
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
          --image-min-tokens 1024 \
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
      granite-4-2-3b = {
        cmd = <<-EOF
        $${default_cmd} \
          --model $${granite-4-2-3b} \
          --ctx-size 131072 \
          --jinja \
          --top-p 0.95 \
          --no-context-shift
        EOF
        filters = {
          stripParams = "temperature"
          setParamsByID = {
            "$${MODEL_ID}" = {
              temperature = 1.0
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
          "granite-4-2-3b",
        ]
      }
    }
    hooks = {
      on_startup = {
        preload = [
          "granite-4-2-3b",
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
  service_port = local.llama-cpp_port
  resources = {
    requests = {
      memory = "64Gi"
    }
  }
  gpu_resource_claim_ref = {
    resourceClaimName = local.resource_claims.amd-gpu-gfx1151 # using resourceClaim (not template) to share GPU with Sunshine
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