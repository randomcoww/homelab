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

resource "matchbox_group" "vmhost_base" {
  name    = "vmhost_base"
  profile = "${matchbox_profile.vmhost_base.name}"

  selector {
    host = "vmhost_base"
  }

  metadata {
    name         = "vmhost_base"
    default_user = "${var.default_user}"
    disk_size    = 12000
  }
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

    ssh_authorized_key = "cert-authority ${chomp(tls_private_key.ssh.public_key_openssh)}"
    internal_ca   = "${replace(tls_self_signed_cert.root.cert_pem, "\n", "\\n")}"
    internal_key  = "${replace(module.controller_cert.private_key_pem, "\n", "\\n")}"
    internal_cert = "${replace(module.controller_cert.cert_pem, "\n", "\\n")}"

    cert_base_path = "/etc/ssl/certs/internal"
    manifest_url = "https://raw.githubusercontent.com/randomcoww/environment-config/master/manifests/vmhost1"
  }
}


resource "matchbox_group" "vmhost2" {
  name    = "vmhost2"
  profile = "${matchbox_profile.vmhost_live.name}"

  selector {
    mac = "0c-c4-7a-da-b5-a0"
  }

  metadata {
    name        = "vmhost2"
    store_ip    = "192.168.126.252"
    netmask     = "23"
    default_user    = "${var.default_user}"
    hyperkube_image = "${var.hyperkube_image}"

    ssh_authorized_key = "cert-authority ${chomp(tls_private_key.ssh.public_key_openssh)}"
    internal_ca   = "${replace(tls_self_signed_cert.root.cert_pem, "\n", "\\n")}"
    internal_key  = "${replace(module.controller_cert.private_key_pem, "\n", "\\n")}"
    internal_cert = "${replace(module.controller_cert.cert_pem, "\n", "\\n")}"

    cert_base_path = "/etc/ssl/certs/internal"
    manifest_url = "https://raw.githubusercontent.com/randomcoww/environment-config/master/manifests/vmhost2"
  }
}
