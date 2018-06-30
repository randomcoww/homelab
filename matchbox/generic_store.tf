##
## vmhost kickstart renderer
##
resource "matchbox_profile" "generic_store" {
  name           = "host_store"
  generic_config = "${file("./kickstart/store.ks.tmpl")}"
}

##
## kickstart
##
resource "matchbox_group" "generic_store" {
  count   = "${length(var.store_hosts)}"

  name    = "host_${var.store_hosts[count.index]}"
  profile = "${matchbox_profile.generic_store.name}"

  selector {
    host = "${var.store_hosts[count.index]}"
  }

  metadata {
    hostname           = "${var.store_hosts[count.index]}"
    hyperkube_image    = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${chomp(tls_private_key.ssh_ca.public_key_openssh)}"
    default_user       = "${var.default_user}"

    lan_ip        = "${var.store_lan_ips[count.index]}"
    lan_if        = "ens1f1"
    lan_netmask   = "${var.lan_netmask}"
    store_ip      = "${var.store_store_ips[count.index]}"
    store_if      = "ens1f0"
    store_netmask = "${var.store_netmask}"
  }
}
