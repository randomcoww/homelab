output "manifests" {
  value = concat([
    module.statefulset.manifest,
    module.secret.manifest,
    module.service.manifest,
    module.httproute.manifest,
    module.minio-user-secret.manifest,
    module.mcp-client-tls.manifest,
    ],
    module.litestream-overlay.additional_manifests,
  module.juicefs-overlay.additional_manifests)
}