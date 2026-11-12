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
      tag        = "latest@sha256:0b104e2e1117b0ca83a36f3ac6ecda7d9ee948ccea6ead74750a03e1b856229a" # renovate: datasource=docker depName=ghcr.io/searxng/searxng
    }
    searxng-mcp = {
      repository = "docker.io/isokoliuk/mcp-searxng"
      tag        = "2.10.1@sha256:39176ff787129814aa7fbc96250e35b01ccc1bb6586d98ad3963551ba53e405d" # renovate: datasource=docker depName=docker.io/isokoliuk/mcp-searxng
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