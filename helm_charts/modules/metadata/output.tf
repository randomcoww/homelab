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
      checksum = sha256(join("\n", values(var.manifests)))
    })
    }, {
    for path, content in var.manifests :
    "${var.name}/${path}" => content
  })
}