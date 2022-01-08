locals {
  libvirt_interfaces = [
    for network_name in var.interface_device_order :
    merge(var.libvirt_interfaces[network_name], {
      network_name = network_name
    })
  ]
}