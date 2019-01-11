##
## desktop kickstart renderer
## no PXE boot - provide ks endpoint only
##
resource "matchbox_profile" "generic_desktop" {
  name           = "host_desktop"
  generic_config = "${file("${path.module}/templates/kickstart/desktop.ks.tmpl")}"
}

resource "matchbox_group" "generic_desktop" {
  count = "${length(var.desktop_hosts)}"

  name    = "host_${var.desktop_hosts[count.index]}"
  profile = "${matchbox_profile.generic_desktop.name}"

  selector {
    ks = "${var.desktop_hosts[count.index]}"
  }

  metadata {
    hostname     = "${var.desktop_hosts[count.index]}"
    default_user = "${var.default_user}"
    password     = "${var.password}"

    host_if      = "${var.desktop_if}"
    mtu          = "${var.mtu}"
  }
}
