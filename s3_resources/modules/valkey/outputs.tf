output "manifests" {
  value = [
    module.configmap.manifest,
    module.statefulset.manifest,
    module.service.manifest,
    module.service-headless.manifest,
  ]
}