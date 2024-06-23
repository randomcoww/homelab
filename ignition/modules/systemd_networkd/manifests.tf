locals {
  ignition_snippets = [
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      ignition_version    = var.ignition_version
      host_netnum         = var.host_netnum
      tap_interfaces      = var.tap_interfaces
      physical_interfaces = var.physical_interfaces
      wlan_interfaces     = var.wlan_interfaces
      bridge_interfaces   = var.bridge_interfaces
    })
  ]
}