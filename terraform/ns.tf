resource "tls_private_key" "service_account_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "matchbox_group" "ns1" {
  name    = "ns1"
  profile = "${matchbox_profile.ns.name}"

  selector {
    mac = "52:54:00:44:b0:19"
  }

  metadata {
    domain_name = "ns1"
    lan_ip      = "192.168.62.219/23"
    store_ip    = "192.168.126.219/23"
    gateway_ip  = "${var.gateway_ip}"
    hyperkube_image = "${var.hyperkube_image}"
    service_account_key = "${replace(tls_private_key.service_account_key.private_key_pem, "\n", "\\n")}",
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
    domain_name = "ns2"
    lan_ip      = "192.168.62.220/23"
    store_ip    = "192.168.126.220/23"
    gateway_ip  = "${var.gateway_ip}"
    hyperkube_image = "${var.hyperkube_image}"
    service_account_key = "${replace(tls_private_key.service_account_key.private_key_pem, "\n", "\\n")}",
    ssh_authorized_key = "${var.ssh_authorized_key}"
  }
}
