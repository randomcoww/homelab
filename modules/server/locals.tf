locals {
  # assign names for guest interfaces by order
  # libvirt assigns names ens2, ens3 ... ensN in order defined in domain XML
  tap_interfaces = {
    for network_name, tap_interface in var.tap_interfaces :
    network_name => merge(var.networks[network_name], tap_interface, {
      interface_name = network_name
    })
  }

  hardware_interfaces = {
    for hardware_interface_name, hardware_interface in var.hardware_interfaces :
    hardware_interface_name => merge(hardware_interface, {
      vlans = {
        for i, network_name in lookup(hardware_interface, "vlans", []) :
        network_name => merge(var.networks[network_name], {
          interface_name = "${hardware_interface_name}-${network_name}"
        })
      }
    })
  }

  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      interfaces          = local.tap_interfaces
      hardware_interfaces = local.hardware_interfaces
      host_netnum         = var.host_netnum
    })
  ]
}