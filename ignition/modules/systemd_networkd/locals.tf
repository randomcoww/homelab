locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      host_netnum         = var.host_netnum
      tap_interfaces      = var.tap_interfaces
      virtual_interfaces  = var.virtual_interfaces
      hardware_interfaces = var.hardware_interfaces
      wlan_interfaces     = var.wlan_interfaces
      bridge_interfaces   = var.bridge_interfaces
    })
  ]
}