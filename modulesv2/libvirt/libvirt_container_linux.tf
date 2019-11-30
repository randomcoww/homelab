resource "libvirt_domain" "libvirt-container-linux" {
  for_each = var.guests

  xml = chomp(templatefile("${path.module}/../../templates/libvirt/container_linux.xml.tmpl", {
    name     = each.key
    memory   = each.value.memory
    vcpu     = each.value.vcpu
    disk     = each.value.disk
    network  = each.value.network
    hostdev  = each.value.hostdev
    networks = var.networks
  }))
}