locals {
  ignition_snippets = [
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      butane_version      = var.butane_version
      fw_mark             = var.fw_mark
      host_netnum         = var.host_netnum
      physical_interfaces = var.physical_interfaces
      bridge_interfaces   = var.bridge_interfaces
      vlan_interfaces     = var.vlan_interfaces
      networks            = var.networks
      wlan_networks       = var.wlan_networks
      mdns_interfaces = [
        for name, config in var.networks :
        config.interface if lookup(config, "enable_mdns", false)
      ]
      mdns_domain = var.mdns_domain
    })
  ]
}