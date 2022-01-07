locals {
  networks = {
    for network_name, network in var.networks :
    network_name => merge(network, try({
      prefix = "${network.network}/${network.cidr}"
    }, {}))
  }

  # KVM domain interfaces are ens2, ens3 ... ensN in order defined in domain XML
  interface_names = {
    for i, interface in var.domain_interfaces :
    interface.network_name => "ens${i + 2}"
  }

  interfaces = {
    for network_name, network in var.interfaces :
    network_name => merge(local.networks[network_name], network, {
      interface_name = local.interface_names[network_name]
    })
  }

  internal_interface = merge(local.networks.internal, {
    interface_name = local.interface_names.internal
  })
}