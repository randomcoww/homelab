locals {
  params = {
    services         = var.services
    container_images = var.container_images
    kubelet_path     = "/var/lib/kubelet"
    pod_mount_path   = "/var/lib/kubelet/podconfig"
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

output "kubernetes" {
  value = [
    for f in fileset(".", "${path.module}/templates/kubernetes/*") :
    templatefile(f, local.params)
  ]
}