##
## desktop kickstart renderer
## no PXE boot - provide ks endpoint only
##
resource "matchbox_profile" "generic_desktop" {
  name           = "host_desktop"
  generic_config = "${file("${path.module}/templates/kickstart/desktop.ks.tmpl")}"
}

resource "matchbox_group" "generic_desktop" {
  count = "${length(var.vm_hosts)}"

  name    = "host_${var.vm_hosts[count.index]}-desktop"
  profile = "${matchbox_profile.generic_desktop.name}"

  selector {
    ks = "${var.vm_hosts[count.index]}-desktop"
  }

  metadata {
    hostname       = "${var.vm_hosts[count.index]}"
    default_user   = "randomcoww"
    localhome_path = "/localhome"
    password       = "${var.password}"

    store_ip         = "${var.vm_store_ips[count.index]}"
    store_if         = "${var.vm_store_ifs[count.index]}"
    store_netmask    = "${var.store_netmask}"
    store_macvlan_if = "int0"
    lan_if           = "en${var.vm_lan_if}"
    sync_if          = "en${var.vm_sync_if}"
    wan_if           = "en${var.vm_wan_if}"
    mtu              = "${var.mtu}"
  }
}
