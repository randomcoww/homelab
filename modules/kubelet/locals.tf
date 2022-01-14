locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      network_prefix           = var.network_prefix
      host_netnum              = var.host_netnum
      kubelet_container_image  = var.container_images.kubelet
      kubelet_config_path      = "/var/lib/kubelet/config"
      static_pod_manifest_path = "/var/lib/kubelet/manifests"
      static_pod_config_path   = "/var/lib/kubelet/podconfig"
    })
  ]
}