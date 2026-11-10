locals {
  camofox-browser_name      = "camofox"
  camofox-browser_namespace = "ai"
  camofox-browser_port      = 3000
}

module "camofox-browser" {
  source    = "./modules/camofox-browser"
  name      = local.camofox-browser_name
  namespace = local.camofox-browser_namespace
  images = {
    camofox-browser = {
      repository = "ghcr.io/jo-inc/camofox-browser"
      tag        = "1.19.0@sha256:49f8e02f9fb0e191b406845482745efc72f835db06789e3a34e77a6ff1497046" # renovate: datasource=docker depName=ghcr.io/jo-inc/camofox-browser
    }
    camofox-browser-mcp = {
      repository = "ghcr.io/redf0x1/camofox-mcp"
      tag        = "1.17.0@sha256:fc71dfaa3aab937e8ddf87c9cf65d6a997eb3b63b3f8b33e62f4494e43ded17c" # renovate: datasource=docker depName=ghcr.io/redf0x1/camofox-mcp
    }
  }
  extra_envs = {
    /*
    PROXY_HOST         = regex(local.domain_regex, var.scrape_proxy_server).hostname
    PROXY_PORT         = regex(local.domain_regex, var.scrape_proxy_server).port
    PROXY_USERNAME     = var.scrape_proxy_username
    PROXY_PASSWORD     = var.scrape_proxy_password
    */
  }
  extra_mcp_envs = {
    CAMOFOX_HTTP_PORT = local.camofox-browser_port
  }
}

resource "minio_s3_object" "fluxcd-camofox-browser" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.camofox-browser.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "camofox-browser/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}