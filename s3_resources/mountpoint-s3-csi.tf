module "mountpoint-s3-csi" {
  source    = "./modules/mountpoint_s3_csi"
  name      = local.endpoints.mountpoint_s3_csi.name
  namespace = local.endpoints.mountpoint_s3_csi.namespace
  images = {
    mountpoint_s3_csi = {
      repository = regex(local.container_image_regex, local.container_images.mountpoint_s3_csi).depName
      tag        = regex(local.container_image_regex, local.container_images.mountpoint_s3_csi).currentValue
    }
  }
  kubelet_root_path = local.kubernetes.kubelet_root_path
  minio_user        = minio_iam_user.user["mountpoint_s3_csi"]
}

resource "minio_s3_object" "fluxcd-mountpoint-s3-csi" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.mountpoint-s3-csi.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "mountpoint-s3-csi/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.bucket["fluxcd"],
  ]
}
