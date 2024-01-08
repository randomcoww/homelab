output "manifests" {
  value = {
    "${var.name}/Chart.yaml" = yamlencode({
      apiVersion = "v2"
      name       = var.name
      version    = var.release
      type       = "application"
      appVersion = split(":", var.images.transmission)[1]
    })
    "${var.name}/values.yaml" = yamlencode({
      Release = {
        Name      = var.name
        Namespace = var.namespace
      }
    })
    "${var.name}/templates/service.yaml"     = module.service.manifest
    "${var.name}/templates/ingress.yaml"     = module.ingress.manifest
    "${var.name}/templates/secret.yaml"      = module.secret.manifest
    "${var.name}/templates/statefulset.yaml" = module.statefulset.manifest
  }
}