resource "matchbox_group" "gateway1" {
  name    = "gateway1"
  profile = "${matchbox_profile.gateway.name}"

  selector {
    host = "gateway1"
  }

  metadata {
    name        = "gateway1"
    lan_ip      = "192.168.62.217"
    store_ip    = "192.168.126.217"
    netmask     = "23"
    gateway_ip  = "${var.gateway_ip}"
    dns_ip      = "${var.dns_ip}"
    default_user    = "${var.default_user}"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "${module.controller_cert.public_key_openssh}"
  }
}

resource "matchbox_group" "gateway2" {
  name    = "gateway2"
  profile = "${matchbox_profile.gateway.name}"

  selector {
    host = "gateway2"
  }

  metadata {
    name        = "gateway2"
    lan_ip      = "192.168.62.218"
    store_ip    = "192.168.126.218"
    netmask     = "23"
    gateway_ip  = "${var.gateway_ip}"
    dns_ip      = "${var.dns_ip}"
    default_user    = "${var.default_user}"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "${module.controller_cert.public_key_openssh}"
  }
}
