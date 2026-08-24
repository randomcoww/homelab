module "generate-backup-disk" {
  source    = "./modules/generate-backup-disk"
  name      = "generate-backup-disk"
  namespace = "default"
  images = {
    backup-runner = {
      repository = "registry.fedoraproject.org/fedora-minimal"
      tag        = "latest@sha256:fb20d0a6558889c2bcc038ac77e2be551e3f989fc54b03e7cc5c90a539035b72" # renovate: datasource=docker depName=registry.fedoraproject.org/fedora-minimal
    }
  }
  cosa_build_tag_karg = local.netboot_custom_kargs.build_tag
  liveiso_url_karg    = local.netboot_custom_kargs.liveiso_url
}

resource "minio_s3_object" "fluxcd-generate-backup-disk" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.generate-backup-disk.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "generate-backup-disk/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}
