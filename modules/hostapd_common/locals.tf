locals {
  roaming_members = {
    for host_key, interface in var.roaming_interfaces :
    host_key => {
      interface_name = interface.interface_name
      bssid          = replace(interface.mac, "-", ":")
      nas_identifier = replace(interface.mac, "/[-:]/", "")
    }
  }
}