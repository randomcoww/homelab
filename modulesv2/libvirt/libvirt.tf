resource "libvirt_domain" "libvirt" {
  for_each = var.libvirt_domains
  xml      = each.value
}