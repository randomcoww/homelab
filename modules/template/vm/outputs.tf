locals {
  params = {
    user             = var.user
    kubelet_path     = "/var/lib/kubelet"
    container_images = var.container_images
  }
}

output "ignition" {
  value = {
    for host, params in var.hosts :
    host => [
      for f in fileset(".", "${path.module}/templates/ignition/*") :
      templatefile(f, merge(local.params, {
        p = params
      }))
    ]
  }
}