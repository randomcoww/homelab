locals {
  searxng_name      = "searxng"
  searxng_namespace = "default"
  searxng_port      = 8080
}

module "searxng" {
  source    = "./modules/searxng"
  name      = local.searxng_name
  namespace = local.searxng_namespace
  replicas  = 2
  images = {
    searxng = {
      repository = "ghcr.io/searxng/searxng"
      tag        = "latest@sha256:f4c8e59de166ed71f6380c0847c312ca51f0d41996e31d0559163b6b09ecde52" # renovate: datasource=docker depName=ghcr.io/searxng/searxng
    }
  }
  extra_configs = {
    SEARXNG_PORT = local.searxng_port
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
}

resource "minio_s3_object" "fluxcd-searxng" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.searxng.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "searxng/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}