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

    host_ip      = "${var.desktop_ips[count.index]}"
    host_if      = "${var.desktop_if}"
    host_netmask = "${var.desktop_netmask}"
    br_ip        = "${var.br_ip}"
    br_if        = "${var.br_if}"
    br_netmask   = "${var.br_netmask}"
    mtu          = "${var.mtu}"
  }
}
