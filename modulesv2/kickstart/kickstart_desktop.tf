
##
## Desktop (HW) kickstart renderer
##
resource "matchbox_group" "ks-desktop" {
  for_each = var.desktop_params

  profile = matchbox_profile.generic-profile.name
  name    = each.key
  selector = {
    ks = each.value.hostname
  }

  metadata = {
    config = templatefile("${path.module}/../../templates/kickstart/desktop.ks.tmpl", each.value)
  }
}