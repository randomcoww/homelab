module "llama-cpp-small" {
  source    = "./modules/llama-cpp"
  name      = "llama-cpp-small"
  replicas  = 0
  namespace = local.llama-cpp_namespace # must be in same namespace as sunshine to share GPU
  images = {
    llama-swap = {
      repository = "zot.cluster.internal/randomcoww/llama-swap-vulkan"
      tag        = "v11030.20260920.1789970262@sha256:424a0147a652c1bf0393ed564b339a48817a983663c2b21d294ea4989307eb7a" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/llama-swap-vulkan
    }
  }
  image_volumes = flatten(concat([
    for _, image in [
      {
        repository = "zot.cluster.internal/randomcoww/granite-4.2-3b-q8-0"
        tag        = "v1788247923@sha256:4174ba613c266d09fa2fa4c854e948b28c10d067a7ce71966b56bc88c92059d5" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/granite-4.2-3b-q8-0
        files = [
          {
            file = "granite-4.2-3b-Q8_0.gguf"
            path = "granite-4-2-3b"
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
      granite-4-2-3b = {
        cmd = <<-EOF
        $${default_cmd} \
          --model $${granite-4-2-3b} \
          --ctx-size 131072 \
          --jinja \
          --top-p 0.95 \
          --temperature 1.0 \
          --no-context-shift
        EOF
      }
    }
    groups = {
      persist = {
        swap       = false
        exclusive  = false
        persistent = true
        members = [
          "granite-4-2-3b",
        ]
      }
    }
    hooks = {
      on_startup = {
        preload = [
          "granite-4-2-3b",
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
      memory = "6Gi"
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