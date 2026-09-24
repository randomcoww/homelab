module "llama-cpp-small" {
  source    = "./modules/llama-cpp"
  name      = "llama-cpp-small"
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
      memory = "2Gi"
    }
    limits = {
      memory = "2Gi"
    }
  }
  gpu_resource_claim_ref = {
    resourceClaimTemplateName = local.resource_claims.amd-gpu-gfx90c
  }
}

resource "minio_s3_object" "fluxcd-llama-cpp-small" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.llama-cpp-small.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "llama-cpp-small/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}