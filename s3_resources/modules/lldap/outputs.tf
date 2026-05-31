output "manifests" {
  value = concat([
    module.statefulset.manifest,
    module.service.manifest,
    module.httproute.manifest,
    module.secret.manifest,
    module.tls.manifest,
    module.minio-user-secret.manifest,
  ], module.litestream-overlay.additional_manifests)
}