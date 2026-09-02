data "http" "inference-extension-crds-yaml" {
  url = join("/", [
    "https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/download",
    "v1.6.0", # renovate: datasource=github-releases depName=kubernetes-sigs/gateway-api-inference-extension
    "v1-manifests.yaml",
  ])
  request_headers = {
    Accept = "application/yaml"
  }
}

resource "minio_s3_object" "inference-extension-crds" {
  for_each = {
    "manifest.yaml" = data.http.inference-extension-crds-yaml.response_body
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "inference-extension-crds/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}