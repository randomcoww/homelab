##
## Ignition renderer for PXE boot CoreOS VMs
##
data "ct_config" "ign-pxe" {
  for_each = var.pxe_ignition_params

  content = templatefile(each.value.templates[0], each.value)
  strict  = true

  snippets = [
    for k in slice(each.value.templates, 1, length(each.value.templates) - 1) :
    templatefile(k, each.value)
  ]
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
    "ip=${each.value.host_network.int.if}:dhcp"
  ])

  raw_ignition = data.ct_config.ign-pxe[each.key].rendered
}

resource "matchbox_group" "ign-pxe" {
  for_each = var.pxe_ignition_params

  profile = matchbox_profile.ign-pxe[each.key].name
  name    = each.key
  selector = {
    mac = each.value.host_network.int.mac
  }
}