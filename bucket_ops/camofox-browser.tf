locals {
  camofox-browser_name      = "camofox"
  camofox-browser_namespace = "default"
  camofox-browser_port      = 9377
}

resource "random_password" "camofox-browser-auth-token" {
  length           = 32
  override_special = "-_"
}

module "camofox-browser" {
  source    = "./modules/camofox-browser"
  name      = local.camofox-browser_name
  namespace = local.camofox-browser_namespace
  images = {
    camofox-browser = {
      repository = "ghcr.io/jo-inc/camofox-browser"
      tag        = "1.14.0@sha256:86c79eed8a6b3a78859f73bc70d6003c5566b85e969354ec454524b28197ffce" # renovate: datasource=docker depName=ghcr.io/jo-inc/camofox-browser
    }
  }
  extra_envs = {
    /* Residential proxy
    PROXY_HOST         = regex(local.domain_regex, var.scrape_proxy_server).hostname
    PROXY_PORT         = regex(local.domain_regex, var.scrape_proxy_server).port
    PROXY_USERNAME     = var.scrape_proxy_username
    PROXY_PASSWORD     = var.scrape_proxy_password
    */
    CAMOFOX_ACCESS_KEY = random_password.camofox-browser-auth-token.result
    CAMOFOX_PORT       = local.camofox-browser_port
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