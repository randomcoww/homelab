##
## LiveOS base template renderer
##

resource "matchbox_profile" "ks-live" {
  name           = "live"
  generic_config = file("${path.module}/../../templates/kickstart/live.ks.tmpl")
}

resource "matchbox_group" "ks-live" {
  for_each = var.live_hosts

  profile = matchbox_profile.ks-live.name
  name    = each.key
  selector = {
    ks = each.key
  }
}