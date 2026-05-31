output "manifests" {
  value = [
    module.configmap.manifest,
    module.tls.manifest,
    module.statefulset.manifest,
    module.service.manifest,
    module.service-headless.manifest,
  ]
}