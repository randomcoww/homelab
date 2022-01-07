

output "ignition" {
  value = concat([
    for f in concat(tolist(fileset(".", "${path.module}/ignition/*.yaml")), [
      "${path.root}/common_templates/ignition/base.yaml",
      "${path.root}/common_templates/ignition/server.yaml",
    ]) :
    templatefile(f, {
      matchbox_data_path    = "/etc/matchbox/data"
      matchbox_assets_path  = "/etc/matchbox/assets"
      kea_config_path       = "/etc/kea/kea-dhcp4-internal.conf"
      user                  = var.user
      hostname              = var.hostname
      ports                 = var.ports
      container_image_paths = var.container_image_paths
      hardware_interfaces   = local.hardware_interfaces
      internal_interface    = local.internal_interface
      certs                 = local.certs
    })
    ],
    module.template-ssh_server.ignition,
  )
}

output "matchbox_rpc_endpoints" {
  value = {
    for network_name, network in local.networks :
    network_name => compact([
      for interface in values(local.hardware_interfaces) :
      try("${cidrhost(
        network.prefix,
        interface[network_name].netnum,
      )}:${var.ports.matchbox_rpc}", null)
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
    for network_name, network in local.networks :
    network_name => compact([
      for interface in values(local.hardware_interfaces) :
      try("qemu://${cidrhost(
        network.prefix,
        interface[network_name].netnum,
      )}/system", null)
    ])
  }
}