module "device-plugin" {
  source    = "./modules/device-plugin"
  name      = "device-plugin"
  namespace = "host-system"
  images = {
    device-plugin = {
      repository = "ghcr.io/squat/generic-device-plugin"
      tag        = "0.2.0@sha256:66c8d5c270eb2b721f1064c549b9b7898152a6d2f0163380a5d37dc7636c20ff" # renovate: datasource=docker depName=ghcr.io/squat/generic-device-plugin
    }
  }
  kubelet_root_path = local.kubernetes.kubelet_root_path
}

resource "minio_s3_object" "fluxcd-device-plugin" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.device-plugin.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "device-plugin/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}