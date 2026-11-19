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
      tag        = "latest@sha256:5b72d7ef63a3d214c2a690016ecf53a17f1ab7f02dcc4a1de1669837d9340fc9" # renovate: datasource=docker depName=ghcr.io/searxng/searxng
    }
    searxng-mcp = {
      repository = "docker.io/isokoliuk/mcp-searxng"
      tag        = "2.11.0@sha256:5247ef2c87a2e33f5e5a73a9d05001a6415488060f667c32b732159bca55b45d" # renovate: datasource=docker depName=docker.io/isokoliuk/mcp-searxng
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