output "manifests" {
  value = merge({
    "${var.name}/Chart.yaml" = yamlencode({
      apiVersion = "v2"
      name       = var.name
      version    = var.release
      type       = "application"
      appVersion = var.app_version
    })
    "${var.name}/values.yaml" = yamlencode({
      Release = {
        Name      = var.name
        Namespace = var.namespace
      }
      files = {
        for path, content in var.manifests :
        "${var.name}/${path}" => sha256(content)
      }
    })
    }, {
    for path, content in var.manifests :
    "${var.name}/${path}" => content
  })
}