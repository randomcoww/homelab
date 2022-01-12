
output "libvirt_endpoints" {
  value = {
    for network_name, network in var.networks :
    network_name => concat([
      for tap_interface in values(local.tap_interfaces) :
      "qemu://${cidrhost(tap_interface.prefix, var.netnums.host)}/system"
      if lookup(tap_interface, "enable_netnum", false)
    ])
  }
}