##
## kvm ignition renderer
##
resource "matchbox_group" "ign-kvm" {
  for_each = var.kvm_params

  profile = matchbox_profile.profile-noop.name
  name    = each.key
  selector = {
    ign = each.value.hostname
  }
  metadata = {
    config = templatefile("${path.module}/../../templates/ignition/kvm.ign.tmpl", each.value)
  }
}