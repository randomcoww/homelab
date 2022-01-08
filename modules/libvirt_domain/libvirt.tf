resource "libvirt_domain" "domain" {
  for_each = var.hosts

  xml = templatefile("${path.module}/libvirt/domain.xml", {
    name   = each.key
    memory = each.value.memory
    vcpu   = each.value.vcpu
    interface_devices = {
      for network_name, interface in each.value.interface_devices :
      network_name => network_name == each.value.pxeboot_interface ? merge(interface, {
        macaddress = each.value.pxeboot_macaddress
      }) : interface
    }
    pxeboot_macaddress = each.value.pxeboot_macaddress
    pxeboot_interface  = each.value.pxeboot_interface
    hypervisor_devices = each.value.hypervisor_devices
    system_image_tag   = each.value.system_image_tag
  })
}