resource "libvirt_domain" "libvirt-container-linux" {
  for_each = var.guests

  xml = chomp(templatefile(each.value.libvirt_template, {
    name     = each.key
    memory   = each.value.memory
    vcpu     = each.value.vcpu
    disk     = each.value.disk
    network  = each.value.network
    hostdev  = each.value.hostdev
    networks = var.networks
  }))
}