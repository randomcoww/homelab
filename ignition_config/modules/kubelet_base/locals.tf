locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      node_ip                  = var.node_ip
      static_pod_manifest_path = var.static_pod_manifest_path
      container_storage_path   = var.container_storage_path
      config_path              = "/var/lib/kubelet/config"
    })
  ]
}