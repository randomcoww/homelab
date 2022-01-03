output "ignition" {
  value = [
    for f in concat(fileset(".", "${path.module}/ignition/*"), [
      "${path.module}/../common_templates/ignition/base.yaml",
      "${path.module}/../common_templates/ignition/server.yaml",
    ]) :
    templatefile(f, {
      matchbox_data_path   = "/etc/matchbox/data"
      matchbox_assets_path = "/etc/matchbox/assets"
      kea_config_path = "/etc/kea/kea-dhcp4.conf"
      user                = var.user
      ports = var.ports
      image_paths = var.image_paths
      vlans = local.vlans
      interfaces = local.interfaces
      internal_interface = local.internal_interface
      certs = local.certs
    })
  ]
}

output "matchbox_rpc_endpoints" {
  value = {
    for network_name in local.vlans :
    network_name => compact([
      for interface in values(local.interfaces) :
      try(join(":", [interface.taps[network_name].address, var.ports.matchbox_rpc]), null)
    ])
  }
}

output "matchbox_http_endpoint" {
  value = join(":", [local.internal_interface.ip, var.ports.matchbox_http])
}

output "libvirt_endpoints" {
  value = {
    for network_name in local.vlans :
    network_name => compact([
      for interface in values(local.interfaces) :
      try("qemu://${interface.taps[network_name].address}/system", null)
    ])
  }
}