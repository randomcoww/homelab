output "ignition" {
  value = [
    for f in concat(tolist(fileset(".", "${path.module}/ignition/*.yaml")), [
      "${path.module}/../common_templates/ignition/base.yaml",
      "${path.module}/../common_templates/ignition/server.yaml",
      "${path.module}/../common_templates/ignition/vm.yaml",
      "${path.module}/../common_templates/ignition/masterless_kubelet.yaml",
    ]) :
    templatefile(f, {
      kubelet_config_path = "/var/lib/kubelet"
      pod_mount_path      = "/var/lib/kubelet/podconfig"
      user                = var.user
      hostname            = var.hostname
      vlans               = local.vlans
      interfaces          = local.interfaces
      internal_interface = {
        name = local.interface_names.internal
      }
      kubelet_node_ip      = local.interfaces.sync.ip
      domain_interfaces    = var.domain_interfaces
      master_default_route = var.master_default_route
      slave_default_route  = var.slave_default_route
      container_images     = var.container_images
      upstream_dns         = var.upstream_dns
    })
  ]
}