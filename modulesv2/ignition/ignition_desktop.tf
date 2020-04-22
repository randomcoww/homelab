##
## desktop ignition renderer
##
resource "matchbox_group" "ign-desktop" {
  for_each = var.desktop_params

  profile = matchbox_profile.profile-noop.name
  name    = each.key
  selector = {
    ign = each.value.hostname
  }
  metadata = {
    config = templatefile("${path.module}/../../templates/ignition/desktop.ign.tmpl", each.value)
  }
}