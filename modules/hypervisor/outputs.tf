

output "ignition_snippets" {
  value = concat([
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      matchbox_data_path         = "/etc/matchbox/data"
      matchbox_assets_path       = "/etc/matchbox/assets"
      pxeboot_image_path         = "/run/media/iso/images/pxeboot"
      kea_config_path            = "/etc/kea/kea-dhcp4-internal.conf"
      ports                      = var.ports
      container_images           = var.container_images
      container_image_load_paths = var.container_image_load_paths
      hardware_interfaces        = local.hardware_interfaces
      internal_interface         = local.internal_interface
      certs                      = local.certs
    })
    ], [
    templatefile("${path.root}/common_templates/ignition/base.yaml", {
      users    = [var.user]
      hostname = var.hostname
    }),
    templatefile("${path.root}/common_templates/ignition/server.yaml", {
    }),
  ])
}

output "hardware_interfaces" {
  value = local.hardware_interfaces
}

output "matchbox_rpc_endpoints" {
  value = {
    for network_name, network in var.networks :
    network_name => compact([
      for hardware_interface in values(local.hardware_interfaces) :
      "${cidrhost(network.prefix, hardware_interface.netnum)}:${var.ports.matchbox_rpc}"
      if try(hardware_interface.interfaces[network_name].enable_netnum, false)
    ])
  }
}

output "matchbox_http_endpoint" {
  value = "http://${cidrhost(local.internal_interface.prefix, local.internal_interface.netnum)}:${var.ports.matchbox_http}"
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