output "manifests" {
  value = [
    module.secret.manifest,
    module.statefulset.manifest,
  ]
}