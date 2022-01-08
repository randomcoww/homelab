output "libvirt" {
  value = templatefile("${path.root}/common_templates/libvirt/domain.xml", {
    name               = var.name
    memory             = var.memory
    vcpus              = var.vcpus
    libvirt_interfaces = local.libvirt_interfaces
    hypervisor_devices = var.hypervisor_devices
    system_image_tag   = var.system_image_tag
  })
}