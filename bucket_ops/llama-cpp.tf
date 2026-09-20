locals {
  llama-cpp_port      = 8080
  llama-cpp_namespace = "default"
}

resource "random_password" "llama-cpp-api-key" {
  length           = 32
  override_special = "-_"
}

module "llama-cpp" {
  source    = "./modules/llama-cpp"
  name      = "llama-cpp"
  replicas  = 1
  namespace = local.llama-cpp_namespace # must be in same namespace as sunshine to share GPU
  images = {
    llama-swap = {
      repository = "zot.cluster.internal/randomcoww/llama-swap-ffmpeg"
      tag        = "unified-vulkan-2026-09-10.1789405863@sha256:a5dde84c97bcaebd27cf4fca666d8b66a241ccd1f46cdb6700c2786e5f00b988" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/llama-swap-ffmpeg
    }
  }
  image_volumes = flatten(concat([
    for _, image in [
      {
        repository = "zot.cluster.internal/randomcoww/qwen3.8-flash-next-ud-q4-k-xl"
        tag        = "v1789811911@sha256:36300dac74c1ed3d1dafbb125c58a6a6ea8ed8664f6a16a6261f4a21f1d873ec" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/qwen3.8-flash-next-ud-q4-k-xl
        files = [
          {
            file = "Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf"
            path = "qwen-3-8-flash-next"
          },
          {
            file = "mmproj-BF16.gguf"
            path = "qwen-3-8-flash-next-mmproj"
          },
        ]
      },
      {
        repository = "zot.cluster.internal/randomcoww/whisper-large-v3-turbo-q8-0"
        tag        = "v1787900300@sha256:3a5b69ec71b585ac016b190ebcdbae1ac4ac19b3e3f393c31c08c709b851429a" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/whisper-large-v3-turbo-q8-0
        files = [
          {
            file = "ggml-large-v3-turbo-q8_0.bin"
            path = "whisper-large-v3-turbo"
          },
        ]
      },
      ] : [
      for _, file in image.files :
      merge(file, {
        image = "${image.repository}:${image.tag}"
      })
    ]
  ]))
  api_keys = [
    random_password.llama-cpp-api-key.result,
  ]
  llama_swap_config = {
    includeAliasesInList = true
    models = {
      qwen-3-8-flash-next = {
        cmd = <<-EOF
        $${default_cmd} \
          --model $${qwen-3-8-flash-next} \
          --ctx-size 262144 \
          --jinja \
          --reasoning-preserve \
          --no-context-shift \
          --lazy-mode on \
          --image-min-tokens 1024 \
          --mmproj $${qwen-3-8-flash-next-mmproj}
        EOF
        filters = {
          stripParams = "temperature,top_p,top_k,min_p,repeat_penalty,presence_penalty"
          setParamsByID = {
            "$${MODEL_ID}" = {
              temperature      = 1.0
              top_p            = 0.95
              top_k            = 20
              min_p            = 0.0
              repeat_penalty   = 1.0
              presence_penalty = 0.0
              reasoning_effort = "xhigh"
            }
            "$${MODEL_ID}-low" = {
              temperature      = 0.7
              top_p            = 0.80
              top_k            = 20
              min_p            = 0.0
              repeat_penalty   = 1.0
              presence_penalty = 1.5
              reasoning_effort = "low"
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
          "qwen-3-8-flash-next",
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
      memory = "96Gi"
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

# outputs

output "llama-cpp-api-key" {
  value     = random_password.llama-cpp-api-key.result
  sensitive = true
}