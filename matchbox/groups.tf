resource "matchbox_group" "ns1" {
  name    = "ns1"
  profile = "${matchbox_profile.ns.name}"

  selector {
    mac = "52:54:00:44:b0:19"
  }

  metadata {
    name        = "ns1"
    lan_ip      = "192.168.62.219/23"
    store_ip    = "192.168.126.219/23"
    gateway_ip  = "${var.gateway_ip}"
    dns_ip      = "127.0.0.1"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "${var.ssh_authorized_key}"
  }
}

resource "matchbox_group" "ns2" {
  name    = "ns2"
  profile = "${matchbox_profile.ns.name}"

  selector {
    mac = "52:54:00:bd:cd:e5"
  }

  metadata {
    name        = "ns2"
    lan_ip      = "192.168.62.220/23"
    store_ip    = "192.168.126.220/23"
    gateway_ip  = "${var.gateway_ip}"
    dns_ip      = "127.0.0.1"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "${var.ssh_authorized_key}"
  }
}

resource "matchbox_group" "gateway1" {
  name    = "gateway1"
  profile = "${matchbox_profile.gateway.name}"

  selector {
    mac = "52:54:00:88:00:a2"
  }

  metadata {
    name        = "gateway1"
    lan_ip      = "192.168.62.217/23"
    store_ip    = "192.168.126.217/23"
    gateway_ip  = "${var.gateway_ip}"
    dns_ip      = "${var.dns_ip}"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "${var.ssh_authorized_key}"
  }
}

resource "matchbox_group" "gateway2" {
  name    = "gateway2"
  profile = "${matchbox_profile.gateway.name}"

  selector {
    mac = "52:54:00:c3:aa:38"
  }

  metadata {
    name        = "gateway2"
    lan_ip      = "192.168.62.218/23"
    store_ip    = "192.168.126.218/23"
    gateway_ip  = "${var.gateway_ip}"
    dns_ip      = "${var.dns_ip}"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "${var.ssh_authorized_key}"
  }
}
