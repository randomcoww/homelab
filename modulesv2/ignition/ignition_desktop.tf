##
## desktop ignition renderer
##
data "ct_config" "ign-desktop" {
  for_each = var.desktop_params

  content = templatefile("${path.module}/../../templates/ignition/desktop.ign.tmpl", each.value)
  strict  = true

  snippets = [
    templatefile("${path.module}/../../templates/ignition/vlan-network.ign.tmpl", each.value),
    templatefile("${path.module}/../../templates/ignition/storage.ign.tmpl", each.value),
    templatefile("${path.module}/../../templates/ignition/base.ign.tmpl", each.value),
  ]
}

resource "matchbox_profile" "ign-desktop" {
  for_each = var.desktop_params

  name         = each.key
  raw_ignition = data.ct_config.ign-desktop[each.key].rendered
}

resource "matchbox_group" "ign-desktop" {
  for_each = var.desktop_params

  profile = matchbox_profile.ign-desktop[each.key].name
  name    = each.key
  selector = {
    ign = each.value.hostname
  }
}