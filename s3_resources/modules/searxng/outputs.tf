output "manifests" {
  value = [
    module.deployment.manifest,
    module.secret.manifest,
    module.service.manifest,
    module.httproute.manifest,
  ]
}