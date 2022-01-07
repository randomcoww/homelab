output "ignition" {
  value = [
    for f in concat(tolist(fileset(".", "${path.module}/ignition/*.yaml")), [
      "${path.root}/common_templates/ignition/base.yaml",
      "${path.root}/common_templates/ignition/server.yaml",
      "${path.root}/common_templates/ignition/vm.yaml",
      "${path.root}/common_templates/ignition/masterless_kubelet.yaml",
    ]) :
    templatefile(f, {
      kubelet_config_path  = "/var/lib/kubelet"
      pod_mount_path       = "/var/lib/kubelet/podconfig"
      kubelet_node_ip      = cidrhost(local.interfaces.sync.prefix, var.netnum)
      user                 = var.user
      hostname             = var.hostname
      interfaces           = local.interfaces
      internal_interface   = local.internal_interface
      master_default_route = var.master_default_route
      slave_default_route  = var.slave_default_route
      container_images     = var.container_images
      upstream_dns         = var.upstream_dns
      netnum               = var.netnum
      vrrp_netnum          = var.vrrp_netnum
    })
  ]
}