output "manifests" {
  value = {
    "${var.name}/Chart.yaml" = yamlencode({
      apiVersion = "v2"
      name       = var.name
      version    = var.release
      type       = "application"
      appVersion = split(":", var.image)[1]
    })
    "${var.name}/templates/secret.yaml"      = module.secret.manifest
    "${var.name}/templates/statefulset.yaml" = module.statefulset.manifest
  }
}