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
      repository = "zot.cluster.internal/randomcoww/llama-swap-vulkan"
      tag        = "v11030.20260921.1790011929@sha256:c79babfc44c04cd384c7f297147ad24b5dae5ddfe271e60312aaff60cf5a68be" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/llama-swap-vulkan
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
        repository = "zot.cluster.internal/randomcoww/qwen3.8-flash-next-ud-q4-k-xl-mtp"
        tag        = "v1789942614@sha256:0f0eb2238cfa510d2205af622cfd1e3353de3062aad8942ecca420d74cfb1e36" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/qwen3.8-flash-next-ud-q4-k-xl-mtp
        files = [
          {
            file = "mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf"
            path = "qwen-3-8-flash-next-mtp"
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
          --spec-draft-model $${qwen-3-8-flash-next-mtp} \
          --spec-type draft-mtp \
          --spec-draft-n-max 5 \
          --cache-type-k q8_0 \
          --cache-type-v q8_0 \
          --mmproj $${qwen-3-8-flash-next-mmproj} \
          --parallel 1 \
          --batch-size 4096 \
          --ubatch-size 1024 \
          --override-tensor 'per_layer_token_embd=CPU'
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
            "$${MODEL_ID}-medium" = {
              temperature      = 0.7
              top_p            = 0.80
              top_k            = 20
              min_p            = 0.0
              repeat_penalty   = 1.0
              presence_penalty = 1.5
              reasoning_effort = "medium"
            }
            "$${MODEL_ID}-none" = {
              temperature      = 0.7
              top_p            = 0.80
              top_k            = 20
              min_p            = 0.0
              repeat_penalty   = 1.0
              presence_penalty = 1.5
              reasoning_effort = "none"
            }
          }
        }
      }
    }
    groups = {
      persist = {
        swap       = false
        exclusive  = false
        persistent = true
        members = [
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