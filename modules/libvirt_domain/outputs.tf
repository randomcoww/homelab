output "libvirt" {
  value = templatefile("${path.module}/libvirt/domain.xml", {
    name               = var.name
    memory             = var.memory
    vcpu               = var.vcpu
    interface_devices  = local.interface_devices
    pxeboot_macaddress = var.pxeboot_macaddress
    pxeboot_interface  = var.pxeboot_interface
    hypervisor_devices = var.hypervisor_devices
    system_image_tag   = var.system_image_tag
  })
}