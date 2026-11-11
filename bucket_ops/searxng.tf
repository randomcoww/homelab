locals {
  searxng_name      = "searxng"
  searxng_namespace = "ai"
  searxng_port      = 3000
}

module "searxng" {
  source    = "./modules/searxng"
  name      = local.searxng_name
  namespace = local.searxng_namespace
  replicas  = 2
  images = {
    searxng = {
      repository = "ghcr.io/searxng/searxng"
      tag        = "latest@sha256:606fc8852a53f0be4ac05116950ff480f6f56b8ef7d77b366868cc76478036e5" # renovate: datasource=docker depName=ghcr.io/searxng/searxng
    }
    searxng-mcp = {
      repository = "docker.io/isokoliuk/mcp-searxng"
      tag        = "2.10.0@sha256:36984f151e3b575b17063eb222ce430dbb8b4bcf3f0abf0e86df18f20731d19b" # renovate: datasource=docker depName=docker.io/isokoliuk/mcp-searxng
    }
  }
  extra_mcp_envs = {
    MCP_HTTP_PORT = local.searxng_port
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
    /*
    outgoing = {
      request_timeout     = 4.0
      extra_proxy_timeout = 10.0
      proxies = {
        "all://:" = [
          "https://${var.scrape_proxy_username}:${var.scrape_proxy_password}@${regex(local.domain_regex, var.scrape_proxy_server).hostname}:${regex(local.domain_regex, var.scrape_proxy_server).port}",
        ]
      }
    }
    */
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