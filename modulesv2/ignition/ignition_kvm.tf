##
## kvm ignition renderer
##
data "ct_config" "ign-kvm" {
  for_each = var.kvm_params

  content = templatefile("${path.module}/../../templates/ignition/kvm.ign.tmpl", each.value)
  strict  = true

  snippets = [
    templatefile("${path.module}/../../templates/ignition/vlan-network.ign.tmpl", each.value),
    templatefile("${path.module}/../../templates/ignition/base.ign.tmpl", each.value),
  ]
}

resource "matchbox_profile" "ign-kvm" {
  for_each = var.kvm_params

  name         = each.key
  raw_ignition = data.ct_config.ign-kvm[each.key].rendered
}

resource "matchbox_group" "ign-kvm" {
  for_each = var.kvm_params

  profile = matchbox_profile.ign-kvm[each.key].name
  name    = each.key
  selector = {
    ign = each.value.hostname
  }
}