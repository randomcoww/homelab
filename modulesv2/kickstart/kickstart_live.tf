##
## LiveOS base template renderer
##
resource "matchbox_group" "ks-live" {
  for_each = var.live_hosts

  profile = matchbox_profile.generic-profile.name
  name    = "live-${each.key}"
  selector = {
    ks = "live-${each.key}"
  }
  metadata = {
    config = templatefile("${path.module}/../../templates/kickstart/live.ks.tmpl", {
    })
  }
}