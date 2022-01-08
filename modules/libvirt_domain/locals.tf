locals {
  # add pxeboot macaddress to internal interface
  interface_devices = {
    for network_name, interface in var.interface_devices :
    network_name => network_name == var.pxeboot_interface ? merge(interface, {
      macaddress = var.pxeboot_macaddress
    }) : interface
  }
}