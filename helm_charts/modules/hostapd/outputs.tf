output "manifests" {
  value = {
    "${var.name}/Chart.yaml" = yamlencode({
      apiVersion = "v2"
      name       = var.name
      version    = var.release
      type       = "application"
      appVersion = split(":", var.images.hostapd)[1]
    })
    "${var.name}/values.yaml" = yamlencode({
      Release = {
        Name      = var.name
        Namespace = var.namespace
      }
    })
    "${var.name}/templates/secret.yaml"      = module.secret.manifest
    "${var.name}/templates/statefulset.yaml" = module.statefulset.manifest
  }
}