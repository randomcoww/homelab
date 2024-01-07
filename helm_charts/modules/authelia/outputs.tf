output "manifests" {
  value = merge({
    "${var.name}/Chart.yaml" = yamlencode({
      apiVersion = "v2"
      name       = var.name
      version    = var.release
      type       = "application"
      appVersion = var.source_release
    })
    "${var.name}/values.yaml" = yamlencode({
      Release = {
        Name      = var.name
        Namespace = var.namespace
      }
    })
    }, {
    for path, content in local.manifests :
    "${var.name}/${path}" => content
  })
}