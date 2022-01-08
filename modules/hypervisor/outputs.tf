

output "ignition_snippets" {
  value = [
    for f in concat(tolist(fileset(".", "${path.module}/ignition/*.yaml")), [
      "${path.root}/common_templates/ignition/base.yaml",
      "${path.root}/common_templates/ignition/server.yaml",
    ]) :
    templatefile(f, {
      matchbox_data_path         = "/etc/matchbox/data"
      matchbox_assets_path       = "/etc/matchbox/assets"
      pxeboot_image_path         = "/run/media/iso/images/pxeboot"
      kea_config_path            = "/etc/kea/kea-dhcp4-internal.conf"
      user                       = var.user
      hostname                   = var.hostname
      ports                      = var.ports
      container_images           = var.container_images
      container_image_load_paths = var.container_image_load_paths
      hardware_interfaces        = local.hardware_interfaces
      internal_interface         = local.internal_interface
      certs                      = local.certs
    })
  ]
}

output "hardware_interfaces" {
  value = local.hardware_interfaces
}

output "matchbox_rpc_endpoints" {
  value = {
    for network_name, network in var.networks :
    network_name => compact([
      for hardware_interface in values(local.hardware_interfaces) :
      "http://${cidrhost(network.prefix, hardware_interface.netnum)}:${var.ports.matchbox_rpc}"
      if try(hardware_interface.interfaces[network_name].enable_netnum, false)
    ])
  }
}

output "matchbox_http_endpoint" {
  value = "${cidrhost(
    "${local.internal_interface.network}/${local.internal_interface.cidr}",
    local.internal_interface.netnum,
  )}:${var.ports.matchbox_http}"
}

output "libvirt_endpoints" {
  value = {
    for network_name, network in var.networks :
    network_name => compact([
      for hardware_interface in values(local.hardware_interfaces) :
      "qemu://${cidrhost(network.prefix, hardware_interface.netnum)}/system"
      if try(hardware_interface.interfaces[network_name].enable_netnum, false)
    ])
  }
}