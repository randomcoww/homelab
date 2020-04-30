##
## gateway ignition renderer
##
data "ct_config" "ign-gateway" {
  for_each = var.gateway_params

  content = templatefile("${path.module}/../../templates/ignition/gateway.ign.tmpl", each.value)
  strict  = true
}

resource "matchbox_profile" "ign-gateway" {
  for_each = var.gateway_params

  name   = each.key
  kernel = "/assets/${var.kernel_image}"
  initrd = [
    for k in var.initrd_images :
    "/assets/${k}"
  ]
  args = concat(var.kernel_params, [
    "ignition.config.url=http://${var.services.renderer.vip}:${var.services.renderer.ports.http}/ignition?mac=$${mac:hexhyp}"
  ])

  raw_ignition = data.ct_config.ign-gateway[each.key].rendered
}

resource "matchbox_group" "ign-gateway" {
  for_each = var.gateway_params

  profile = matchbox_profile.ign-gateway[each.key].name
  name    = each.key
  selector = {
    mac = each.value.host_network.int.mac
  }
}