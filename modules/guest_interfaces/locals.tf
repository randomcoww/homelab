locals {
  # assign names for guest interfaces by order
  # libvirt assigns names ens2, ens3 ... ensN in order defined in domain XML
  interfaces = {
    for network_name, network in var.interfaces :
    network_name => merge(var.networks[network_name], network, {
      interface_name = "ens${index(sort(keys(var.interfaces)), network_name) + 2}"
    })
  }
}