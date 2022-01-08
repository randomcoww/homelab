locals {
  networks = {
    for network_name, network in var.networks :
    network_name => merge(network, try({
      prefix = "${network.network}/${network.cidr}"
    }, {}))
  }

  interface_device_order = [
    for network_name in var.interface_device_order :
    network_name
    if can(var.interfaces[network_name])
  ]

  interface_names = {
    for i, network_name in local.interface_device_order :
    network_name => "ens${i + 2}"
  }

  interfaces = {
    for network_name, network in var.interfaces :
    network_name => merge(local.networks[network_name], network, {
      interface_name = local.interface_names[network_name]
    })
  }
}