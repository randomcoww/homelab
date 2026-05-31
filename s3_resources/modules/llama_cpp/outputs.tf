output "manifests" {
  value = [
    module.statefulset.manifest,
    module.service.manifest,
    module.httproute.manifest,
    module.secret.manifest,
  ]
}