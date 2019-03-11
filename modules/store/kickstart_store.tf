##
## vmhost kickstart renderer
##
resource "matchbox_profile" "generic_store" {
  name           = "host_store"
  generic_config = "${file("${path.module}/templates/kickstart/store.ks.tmpl")}"
}

resource "matchbox_group" "generic_store" {
  count = "${length(var.store_hosts)}"

  name    = "host_${var.store_hosts[count.index]}"
  profile = "${matchbox_profile.generic_store.name}"

  selector {
    ks = "${var.store_hosts[count.index]}"
  }

  metadata {
    hostname           = "${var.store_hosts[count.index]}"
    ssh_authorized_key = "cert-authority ${chomp(var.ssh_ca_public_key)}"
    default_user       = "${var.default_user}"
    password           = "${var.password}"

    host_ip      = "${var.store_ips[count.index]}"
    host_if      = "${var.store_if}"
    host_netmask = "${var.store_netmask}"
    ll_if        = "${var.ll_if}"
    ll_ip        = "${var.ll_ip}"
    ll_netmask   = "${var.ll_netmask}"
    mtu          = "${var.mtu}"
  }
}
