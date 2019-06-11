##
## vmhost kickstart renderer
##
resource "matchbox_profile" "generic_live" {
  name           = "host_live"
  generic_config = "${file("${path.module}/templates/kickstart/live.ks.tmpl")}"
}

resource "matchbox_group" "generic_live" {
  name    = "host_live"
  profile = "${matchbox_profile.generic_live.name}"

  selector {
    ks = "live-base"
  }

  metadata {
    ll_ip         = "${var.ll_ip}"
    ll_if         = "${var.ll_if}"
    ll_netmask    = "${var.ll_netmask}"
    ll_macvtap_if = "int1"
    dummy_if      = "dummy0"
    mtu           = "${var.mtu}"
  }
}
