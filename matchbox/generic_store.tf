##
## vmhost kickstart renderer
##
resource "matchbox_profile" "generic_store" {
  name   = "generic_store"
  generic_config = "${file("./kickstart/store.ks.tmpl")}"
}


##
## kickstart
##
resource "matchbox_group" "generic_store_0" {
  name    = "generic_store_0"
  profile = "${matchbox_profile.generic_store.name}"

  selector {
    host = "store_0"
  }

  metadata {
    hostname      = "store-0"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${chomp(tls_private_key.ssh_ca.public_key_openssh)}"
    default_user  = "${var.default_user}"

    lan_ip        = "192.168.62.251"
    lan_if        = "ens1f1"
    lan_netmask   = "${var.lan_netmask}"
    store_ip      = "192.168.126.251"
    store_if      = "ens1f0"
    store_netmask = "${var.store_netmask}"
  }
}

resource "matchbox_group" "generic_store_1" {
  name    = "generic_store_1"
  profile = "${matchbox_profile.generic_store.name}"

  selector {
    host = "store_1"
  }

  metadata {
    hostname      = "store-1"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${chomp(tls_private_key.ssh_ca.public_key_openssh)}"
    default_user  = "${var.default_user}"

    lan_ip        = "192.168.62.252"
    lan_if        = "ens1f1"
    lan_netmask   = "${var.lan_netmask}"
    store_ip      = "192.168.126.252"
    store_if      = "ens1f0"
    store_netmask = "${var.store_netmask}"
  }
}
