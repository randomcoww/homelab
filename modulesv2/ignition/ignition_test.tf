##
## test ignition renderer
##
data "ct_config" "ign-test" {
  for_each = var.test_params

  content = templatefile("${path.module}/../../templates/ignition/test.ign.tmpl", each.value)
  strict  = true

  snippets = [
    templatefile("${path.module}/../../templates/ignition/base.ign.tmpl", each.value),
    templatefile("${path.module}/../../templates/ignition/containerd.ign.tmpl", each.value),
  ]
}

resource "matchbox_profile" "ign-test" {
  for_each = var.test_params

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

  raw_ignition = data.ct_config.ign-test[each.key].rendered
}

resource "matchbox_group" "ign-test" {
  for_each = var.test_params

  profile = matchbox_profile.ign-test[each.key].name
  name    = each.key
  selector = {
    mac = each.value.host_network.int.mac
  }
}