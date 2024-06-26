locals {
  ignition_snippets = [
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      ignition_version    = var.ignition_version
      host_netnum         = var.host_netnum
      physical_interfaces = var.physical_interfaces
      bridge_interfaces   = var.bridge_interfaces
      vlan_interfaces     = var.vlan_interfaces
      networks            = var.networks
      wlan_networks       = var.wlan_networks
    })
  ]
}