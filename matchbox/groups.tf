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
    default_user    = "${var.default_user}"
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
    default_user    = "${var.default_user}"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "${var.ssh_authorized_key}"
  }
}


module "ns1_cert" {
  source = "../modules/cert"
  common_name = "ns1"
  ca_key_algorithm   = "${tls_private_key.root.algorithm}"
  ca_private_key_pem = "${tls_private_key.root.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.root.cert_pem}"
  ip_addresses = [
    "192.168.62.219",
    "192.168.126.219"
  ]
  dns_names = [
    "*.internal"
  ]
}

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

    internal_ca   = "${replace(tls_self_signed_cert.root.cert_pem, "\n", "\\n")}"
    internal_key  = "${replace(module.ns1_cert.private_key_pem, "\n", "\\n")}"
    internal_cert = "${replace(module.ns1_cert.cert_pem, "\n", "\\n")}"
  }
}


module "ns2_cert" {
  source = "../modules/cert"
  common_name = "ns2"
  ca_key_algorithm   = "${tls_private_key.root.algorithm}"
  ca_private_key_pem = "${tls_private_key.root.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.root.cert_pem}"
  ip_addresses = [
    "192.168.62.220",
    "192.168.126.220"
  ]
  dns_names = [
    "*.internal"
  ]
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
    default_user   = "${var.default_user}"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "${var.ssh_authorized_key}"

    internal_ca   = "${replace(tls_self_signed_cert.root.cert_pem, "\n", "\\n")}"
    internal_key  = "${replace(module.ns2_cert.private_key_pem, "\n", "\\n")}"
    internal_cert = "${replace(module.ns2_cert.cert_pem, "\n", "\\n")}"
  }
}


module "vmhost1_cert" {
  source = "../modules/cert"
  common_name = "vmhost1"
  ca_key_algorithm   = "${tls_private_key.root.algorithm}"
  ca_private_key_pem = "${tls_private_key.root.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.root.cert_pem}"
  ip_addresses = [
    "192.168.62.251",
    "192.168.126.251"
  ]
  dns_names = [
    "*.internal"
  ]
}

resource "matchbox_group" "vmhost1" {
  name    = "vmhost1"
  profile = "${matchbox_profile.vmhost.name}"

  selector {
    mac = "d6:3d:1f:7b:0b:d0"
  }

  metadata {
    name        = "vmhost1"
    lan_ip      = "192.168.62.251/23"
    store_ip    = "192.168.126.251/23"
    gateway_ip  = "${var.gateway_ip}"
    dns_ip      = "${var.dns_ip}"
    default_user    = "${var.default_user}"
    cluster_dns_ip  = "${var.cluster_dns_ip}"
    cluster_domain  = "${var.cluster_domain}"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "${var.ssh_authorized_key}"

    flannel_conf = "${chomp(var.flannel_conf)}"
    cni_conf     = "${chomp(var.cni_conf)}"
    kubeconfig   = "${chomp(var.kubeconfig_local)}"

    internal_ca   = "${chomp(tls_self_signed_cert.root.cert_pem)}"
    internal_key  = "${chomp(module.vmhost1_cert.private_key_pem)}"
    internal_cert = "${chomp(module.vmhost1_cert.cert_pem)}"
  }
}
