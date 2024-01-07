output "manifests" {
  value = {
    "${var.name}/Chart.yaml" = yamlencode({
      apiVersion = "v2"
      name       = var.name
      version    = var.release
      type       = "application"
      appVersion = split(":", var.images.matchbox)[1]
    })
    "${var.name}/values.yaml" = yamlencode({
      Release = {
        Name      = var.name
        Namespace = var.namespace
      }
    })
    "${var.name}/templates/service.yaml"          = module.service.manifest
    "${var.name}/templates/service-peer.yaml"     = module.service-peer.manifest
    "${var.name}/templates/secret-matchbox.yaml"  = module.secret-matchbox.manifest
    "${var.name}/templates/secret-syncthing.yaml" = module.secret-syncthing.manifest
    "${var.name}/templates/statefulset.yaml"      = module.statefulset.manifest
  }
}