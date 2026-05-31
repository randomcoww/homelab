output "manifests" {
  value = concat([
    module.secret.manifest,
    module.statefulset.manifest,
    module.kea-tls.manifest,
    ], [
    for _, service in module.service-peer :
    service.manifest
  ])
}