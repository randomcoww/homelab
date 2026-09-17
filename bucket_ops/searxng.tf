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
      tag        = "latest@sha256:ba0a344c566ecc6e4429e81d02d93a01fa05c80e9fb6d08f0a1e57a729aa6d87" # renovate: datasource=docker depName=ghcr.io/searxng/searxng
    }
  }
  extra_envs = {
    SEARXNG_PORT = local.searxng_port
  }
  searxng_settings = {
    use_default_settings = true
    engines = [
      {
        name   = "google cse"
        weight = 2.0
      },
    ]
    search = {
      autocomplete = ""
      safe_search  = 0
      default_lang = "auto"
      formats = [
        "json",
      ]
    }
    outgoing = {
      request_timeout     = 4.0
      extra_proxy_timeout = 10.0
      proxies = {
        "all://:" = [
          "https://${var.scrape_proxy_username}:${var.scrape_proxy_password}@${regex(local.domain_regex, var.scrape_proxy_server).hostname}:${regex(local.domain_regex, var.scrape_proxy_server).port}",
        ]
      }
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