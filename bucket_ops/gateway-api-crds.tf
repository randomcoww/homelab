data "http" "gateway-api-crds-yaml" {
  url = join("/", [
    "https://github.com/kubernetes-sigs/gateway-api/releases/download",
    "v1.6.2", # renovate: datasource=github-releases depName=kubernetes-sigs/gateway-api
    "experimental-install.yaml",
  ])
  request_headers = {
    Accept = "application/yaml"
  }
}

resource "minio_s3_object" "gateway-api-crds" {
  for_each = {
    "manifest.yaml" = data.http.gateway-api-crds-yaml.response_body
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "gateway-api-crds/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}