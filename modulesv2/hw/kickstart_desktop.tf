##
## Desktop (HW) kickstart renderer
##
resource "matchbox_group" "ks-desktop" {
  for_each = var.desktop_hosts

  profile = matchbox_profile.ks-profile.name
  name    = each.key
  selector = {
    ks = each.key
  }
  metadata = {
    config = templatefile("${path.module}/../../templates/kickstart/desktop.ks.tmpl", {
      hostname = each.key
      user     = var.user
      password = var.password

      persistent_home_path  = each.value.persistent_home_path
      persistent_home_dev   = each.value.persistent_home_dev
      persistent_home_mount = "${join("-", compact(split("/", each.value.persistent_home_path)))}.mount"
    })
  }
}