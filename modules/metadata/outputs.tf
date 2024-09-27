output "chart" {
  value = {
    name       = var.name
    namespace  = var.namespace
    version    = var.release
    appVersion = var.app_version
    manifests = {
      for path, content in var.manifests :
      "${var.name}/${path}" => content
    }
  }
}