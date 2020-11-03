resource "libvirt_network" "libvirt" {
  for_each = var.networks
  xml      = each.value
}

resource "libvirt_domain" "libvirt" {
  for_each = var.domains
  xml      = each.value
}