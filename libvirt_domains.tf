module "libvirt-domains_hypervisor-0" {
  for_each = local.hypervisor_guest_config.hypervisor-0.guests

  source             = "./modules/libvirt_domain"
  name               = each.key
  vcpu               = each.value.vcpu
  memory             = each.value.memory
  pxeboot_macaddress = each.value.pxeboot_macaddress
  pxeboot_interface  = local.hypervisor_hostclass_config.internal_interface.interface_name
  interface_devices  = each.value.interfaces
  system_image_tag   = local.config.system_image_tags.server
}

resource "local_file" "libvirt-domains_hypervisor-0" {
  for_each = local.hypervisor_guest_config.hypervisor-0.guests

  content  = module.libvirt-domains_hypervisor-0[each.key].libvirt
  filename = "./output/libvirt/${each.key}.xml"
}