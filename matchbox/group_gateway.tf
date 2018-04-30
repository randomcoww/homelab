## gateway
resource "matchbox_profile" "gateway" {
  name   = "gateway"
  container_linux_config = "${file("./ignition/gateway.yaml.tmpl")}"
  kernel = "/assets/coreos/${var.container_linux_version}/coreos_production_pxe.vmlinuz"
  initrd = [
    "/assets/coreos/${var.container_linux_version}/coreos_production_pxe_image.cpio.gz"
  ]
  args = [
    "coreos.config.url=${var.matchbox_http_endpoint}/ignition?mac=$${mac:hexhyp}",
    "coreos.first_boot=yes",
    "console=hvc0",
    "coreos.autologin"
  ]
}


## groups
resource "matchbox_group" "gateway1" {
  name    = "gateway1"
  profile = "${matchbox_profile.gateway.name}"

  selector {
    mac = "52-54-00-32-3a-a1"
  }

  metadata {
    name        = "gateway1.${var.internal_domain}"
    lan_ip      = "192.168.62.217"
    store_ip    = "192.168.126.217"
    sync_ip     = "192.168.190.217"
    netmask     = "23"
    gateway_ip  = "${var.gateway_ip}"
    dns_ip      = "${var.dns_ip}"
    default_user    = "${var.default_user}"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${tls_private_key.ssh.public_key_openssh}"
    manifest_url = "https://raw.githubusercontent.com/randomcoww/environment-config/master/manifests/gateway"
  }
}


resource "matchbox_group" "gateway2" {
  name    = "gateway2"
  profile = "${matchbox_profile.gateway.name}"

  selector {
    mac = "52-54-00-c3-00-46"
  }

  metadata {
    name        = "gateway2.${var.internal_domain}"
    lan_ip      = "192.168.62.218"
    store_ip    = "192.168.126.218"
    sync_ip     = "192.168.190.218"
    netmask     = "23"
    gateway_ip  = "${var.gateway_ip}"
    dns_ip      = "${var.dns_ip}"
    default_user    = "${var.default_user}"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${tls_private_key.ssh.public_key_openssh}"
    manifest_url = "https://raw.githubusercontent.com/randomcoww/environment-config/master/manifests/gateway"
  }
}
