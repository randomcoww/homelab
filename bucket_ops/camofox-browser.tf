resource "random_password" "camofox-browser-auth-token" {
  length           = 32
  override_special = "-_"
}

module "camofox-browser" {
  source    = "./modules/camofox-browser"
  name      = local.endpoints.camofox_browser.name
  namespace = local.endpoints.camofox_browser.namespace
  images = {
    camofox_browser = local.container_images_digest.camofox_browser
  }
  extra_configs = {
    PROXY_HOST         = regex(local.domain_regex, var.scrape_proxy_server).hostname
    PROXY_PORT         = regex(local.domain_regex, var.scrape_proxy_server).port
    PROXY_USERNAME     = var.scrape_proxy_username
    PROXY_PASSWORD     = var.scrape_proxy_password
    CAMOFOX_ACCESS_KEY = random_password.camofox-browser-auth-token.result
  }
  ingress_hostname = local.endpoints.camofox_browser.ingress
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