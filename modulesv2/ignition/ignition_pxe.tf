##
## Ignition renderer for PXE boot CoreOS VMs
##
data "ct_config" "ign-pxe" {
  for_each = var.pxe_ignition_params

  content  = <<EOT
---
variant: fcos
version: 1.0.0
EOT
  strict   = true
  snippets = each.value.templates
}

resource "matchbox_profile" "ign-pxe" {
  for_each = var.pxe_ignition_params

  name   = each.key
  kernel = "/assets/${var.kernel_image}"
  initrd = [
    for k in var.initrd_images :
    "/assets/${k}"
  ]
  args = concat(var.kernel_params, [
    "ignition.config.url=http://${var.services.renderer.vip}:${var.services.renderer.ports.http}/ignition?mac=$${mac:hexhyp}",
    "ip=${each.value.selector.if}:dhcp",
  ])

  raw_ignition = data.ct_config.ign-pxe[each.key].rendered
}

resource "matchbox_group" "ign-pxe" {
  for_each = var.pxe_ignition_params

  profile = matchbox_profile.ign-pxe[each.key].name
  name    = each.key
  selector = {
    mac = each.value.selector.mac
  }
}