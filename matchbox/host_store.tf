##
## vmhost kickstart renderer
##
resource "matchbox_profile" "store" {
  name   = "store"
  generic_config = "${file("./kickstart/store.ks.tmpl")}"
}


##
## kickstart
##
resource "matchbox_group" "store_0" {
  name    = "store_0"
  profile = "${matchbox_profile.store.name}"

  selector {
    host = "store_0"
  }

  metadata {
    hostname      = "store-0"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${chomp(tls_private_key.ssh_ca.public_key_openssh)}"
    default_user  = "${var.default_user}"

    ip_lan        = "192.168.62.251"
    if_lan        = "ens1f1"
    netmask_lan   = "23"
    ip_store      = "192.168.126.251"
    if_store      = "ens1f0"
    netmask_store = "23"
  }
}

resource "matchbox_group" "store_1" {
  name    = "store_1"
  profile = "${matchbox_profile.store.name}"

  selector {
    host = "store_1"
  }

  metadata {
    hostname      = "store-1"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${chomp(tls_private_key.ssh_ca.public_key_openssh)}"
    default_user  = "${var.default_user}"

    ip_lan        = "192.168.62.252"
    if_lan        = "ens1f1"
    netmask_lan   = "23"
    ip_store      = "192.168.126.252"
    if_store      = "ens1f0"
    netmask_store = "23"
  }
}
