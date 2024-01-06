output "manifests" {
  value = merge({
    "${var.name}/Chart.yaml" = yamlencode({
      apiVersion = "v2"
      name       = var.name
      version    = var.release
      type       = "application"
      appVersion = split(":", var.images.kea)[1]
    })
    "${var.name}/values.yaml" = yamlencode({
      Release = {
        Name      = var.name
        Namespace = var.namespace
      }
    })
    "${var.name}/templates/configmap.yaml"   = module.configmap.manifest
    "${var.name}/templates/service.yaml"     = module.service.manifest
    "${var.name}/templates/statefulset.yaml" = module.statefulset.manifest
    },
    {
      for k, service in module.service-peer :
      "${var.name}/templates/service-${k}.yaml" => service.manifest
  })
}