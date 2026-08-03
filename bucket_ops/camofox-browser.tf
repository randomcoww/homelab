resource "random_password" "camofox-browser-auth-token" {
  length           = 32
  override_special = "-_"
}

module "camofox-browser" {
  source    = "./modules/camofox-browser"
  name      = local.endpoints.camofox-browser.name
  namespace = local.endpoints.camofox-browser.namespace
  images = {
    camofox-browser = {
      repository = "ghcr.io/jo-inc/camofox-browser"
      tag        = "1.13.0@sha256:64b30ffdbbc4ae0e28200a66dfbd6f55ac4188229eb34ef769afcf7be40faa6e" # renovate: datasource=docker depName=ghcr.io/jo-inc/camofox-browser
    }
  }
  extra_configs = {
    PROXY_HOST         = regex(local.domain_regex, var.scrape_proxy_server).hostname
    PROXY_PORT         = regex(local.domain_regex, var.scrape_proxy_server).port
    PROXY_USERNAME     = var.scrape_proxy_username
    PROXY_PASSWORD     = var.scrape_proxy_password
    CAMOFOX_ACCESS_KEY = random_password.camofox-browser-auth-token.result
  }
  ingress_hostname = local.endpoints.camofox-browser.ingress
  gateway_ref = {
    name      = local.endpoints.cilium.name
    namespace = local.endpoints.cilium.namespace
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