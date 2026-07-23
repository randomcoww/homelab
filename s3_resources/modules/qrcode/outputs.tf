output "manifests" {
  value = [
    module.service.manifest,
    module.secret.manifest,
    module.httproute.manifest,
    module.deployment.manifest,
  ]
}