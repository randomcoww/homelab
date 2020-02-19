##
## LiveOS base template renderer
##
resource "matchbox_group" "ks-live" {
  profile = matchbox_profile.generic-profile.name
  name    = "live"
  selector = {
    ks = "live"
  }
  metadata = {
    config = templatefile("${path.module}/../../templates/kickstart/live.ks.tmpl", {
    })
  }
}