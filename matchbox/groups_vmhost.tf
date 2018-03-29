module "vmhost_cert" {
  source = "../modules/cert"
  common_name = "vmhost"
  ca_key_algorithm   = "${tls_private_key.root.algorithm}"
  ca_private_key_pem = "${tls_private_key.root.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.root.cert_pem}"
  ip_addresses = [
    "127.0.0.1"
  ]
  dns_names = [
    "*.svc.internal"
  ]
}

resource "matchbox_group" "vmhost1" {
  name    = "vmhost1"
  profile = "${matchbox_profile.vmhost.name}"

  selector {
    host = "vmhost1"
  }

  metadata {
    name        = "vmhost1"
    store_ip    = "192.168.126.251"
    netmask     = "23"
    default_user    = "${var.default_user}"
    hyperkube_image = "${var.hyperkube_image}"

    ssh_authorized_key = "cert-authority ${chomp(tls_private_key.root.public_key_openssh)}"
    internal_ca   = "${chomp(tls_self_signed_cert.root.cert_pem)}"
    internal_key  = "${chomp(module.vmhost_cert.private_key_pem)}"
    internal_cert = "${chomp(module.vmhost_cert.cert_pem)}"

    cert_base_path = "/etc/ssl/certs/internal"
    manifest_url = "https://raw.githubusercontent.com/randomcoww/environment-config/master/manifests/vmhost1"
  }
}

resource "matchbox_group" "vmhost2" {
  name    = "vmhost2"
  profile = "${matchbox_profile.vmhost.name}"

  selector {
    host = "vmhost2"
  }

  metadata {
    name        = "vmhost2"
    store_ip    = "192.168.126.252"
    netmask     = "23"
    default_user    = "${var.default_user}"
    hyperkube_image = "${var.hyperkube_image}"

    ssh_authorized_key = "cert-authority ${chomp(tls_private_key.root.public_key_openssh)}"
    internal_ca   = "${chomp(tls_self_signed_cert.root.cert_pem)}"
    internal_key  = "${chomp(module.vmhost_cert.private_key_pem)}"
    internal_cert = "${chomp(module.vmhost_cert.cert_pem)}"

    cert_base_path = "/etc/ssl/certs/internal"
    manifest_url = "https://raw.githubusercontent.com/randomcoww/environment-config/master/manifests/vmhost2"
  }
}
