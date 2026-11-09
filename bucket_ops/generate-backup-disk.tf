module "generate-backup-disk" {
  source    = "./modules/generate-backup-disk"
  name      = "generate-backup-disk"
  namespace = "host-system"
  images = {
    backup-runner = {
      repository = "zot.cluster.internal/randomcoww/coreos-installer"
      tag        = "v1.1794262458@sha256:60819a2efc5efef1dc6d14b8cbca530d6481f524cc1a4a31ea513fc2e996cb5d" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/coreos-installer
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
