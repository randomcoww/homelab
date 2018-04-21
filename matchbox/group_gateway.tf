## gateway
resource "matchbox_profile" "gateway" {
  name   = "gateway"
  container_linux_config = "${file("./ignition/gateway.yaml.tmpl")}"
}

## groups
resource "matchbox_group" "gateway1" {
  name    = "gateway1"
  profile = "${matchbox_profile.gateway.name}"

  selector {
    host = "gateway1"
  }

  metadata {
    name        = "gateway1.${var.internal_domain}"
    disable_wan = "true"
    lan_ip      = "192.168.62.217"
    store_ip    = "192.168.126.217"
    sync_ip     = "192.168.190.217"
    netmask     = "23"
    gateway_ip  = "${var.gateway_ip}"
    dns_ip      = "${var.dns_ip}"
    default_user    = "${var.default_user}"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${tls_private_key.ssh.public_key_openssh}"
    manifest_url = "https://raw.githubusercontent.com/randomcoww/environment-config/master/manifests/gateway1"
  }
}

resource "matchbox_group" "gateway1_master" {
  name    = "gateway1_master"
  profile = "${matchbox_profile.gateway.name}"

  selector {
    host = "gateway1_master"
  }

  metadata {
    name        = "gateway1.${var.internal_domain}"
    disable_wan = "false"
    lan_ip      = "192.168.62.217"
    store_ip    = "192.168.126.217"
    sync_ip     = "192.168.190.217"
    netmask     = "23"
    gateway_ip  = "${var.gateway_ip}"
    dns_ip      = "${var.dns_ip}"
    default_user    = "${var.default_user}"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${tls_private_key.ssh.public_key_openssh}"
    manifest_url = "https://raw.githubusercontent.com/randomcoww/environment-config/master/manifests/gateway1"
  }
}


resource "matchbox_group" "gateway2" {
  name    = "gateway2"
  profile = "${matchbox_profile.gateway.name}"

  selector {
    host = "gateway2"
  }

  metadata {
    name        = "gateway2.${var.internal_domain}"
    disable_wan = "true"
    lan_ip      = "192.168.62.218"
    store_ip    = "192.168.126.218"
    sync_ip     = "192.168.190.218"
    netmask     = "23"
    gateway_ip  = "${var.gateway_ip}"
    dns_ip      = "${var.dns_ip}"
    default_user    = "${var.default_user}"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${tls_private_key.ssh.public_key_openssh}"
    manifest_url = "https://raw.githubusercontent.com/randomcoww/environment-config/master/manifests/gateway2"
  }
}

resource "matchbox_group" "gateway2_master" {
  name    = "gateway2_master"
  profile = "${matchbox_profile.gateway.name}"

  selector {
    host = "gateway2_master"
  }

  metadata {
    name        = "gateway2.${var.internal_domain}"
    disable_wan = "false"
    lan_ip      = "192.168.62.218"
    store_ip    = "192.168.126.218"
    sync_ip     = "192.168.190.218"
    netmask     = "23"
    gateway_ip  = "${var.gateway_ip}"
    dns_ip      = "${var.dns_ip}"
    default_user    = "${var.default_user}"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${tls_private_key.ssh.public_key_openssh}"
    manifest_url = "https://raw.githubusercontent.com/randomcoww/environment-config/master/manifests/gateway2"
  }
}
