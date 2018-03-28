resource "matchbox_group" "ns1" {
  name    = "ns1"
  profile = "${matchbox_profile.ns.name}"

  selector {
    host = "ns1"
  }

  metadata {
    name        = "ns1"
    lan_ip      = "192.168.62.219"
    store_ip    = "192.168.126.219"
    netmask     = "23"
    gateway_ip  = "${var.gateway_ip}"
    dns_ip      = "127.0.0.1"
    default_user   = "${var.default_user}"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${module.controller_cert.public_key_openssh}"
  }
}

resource "matchbox_group" "ns2" {
  name    = "ns2"
  profile = "${matchbox_profile.ns.name}"

  selector {
    host = "ns2"
  }

  metadata {
    name        = "ns2"
    lan_ip      = "192.168.62.220"
    store_ip    = "192.168.126.220"
    netmask     = "23"
    gateway_ip  = "${var.gateway_ip}"
    dns_ip      = "127.0.0.1"
    default_user   = "${var.default_user}"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${module.controller_cert.public_key_openssh}"
  }
}
