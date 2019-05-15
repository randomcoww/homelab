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
    hostname       = "${var.desktop_hosts[count.index]}"
    desktop_user   = "${var.desktop_user}"
    localhome_path = "${var.localhome_path}"
    password       = "${var.password}"

    store_ip      = "${var.desktop_store_ips[count.index]}"
    store_if      = "${var.desktop_store_if}"
    store_netmask = "${var.store_netmask}"
    ll_ip         = "${var.desktop_ll_ip}"
    ll_if         = "${var.desktop_ll_if}"
    ll_netmask    = "${var.ll_netmask}"
    lan_if        = "en${var.desktop_lan_if}"
    sync_if       = "en${var.desktop_sync_if}"
    wan_if        = "en${var.desktop_wan_if}"
    mtu           = "${var.mtu}"
  }
}
