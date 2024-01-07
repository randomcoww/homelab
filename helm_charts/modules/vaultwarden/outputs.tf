output "manifests" {
  value = merge({
    "${var.name}/Chart.yaml" = yamlencode({
      apiVersion = "v2"
      name       = var.name
      version    = var.release
      type       = "application"
      appVersion = split(":", var.images.vaultwarden)[1]
    })
    "${var.name}/values.yaml" = yamlencode({
      Release = {
        Name      = var.name
        Namespace = var.namespace
      }
    })
    "${var.name}/templates/service.yaml"    = module.service.manifest
    "${var.name}/templates/ingress.yaml"    = module.ingress.manifest
    "${var.name}/templates/deployment.yaml" = module.deployment.manifest
  })
}