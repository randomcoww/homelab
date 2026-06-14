output "manifests" {
  value = [
    module.deployment.manifest,
    module.service.manifest,
    module.httproute.manifest,
    module.secret.manifest,
  ]
}