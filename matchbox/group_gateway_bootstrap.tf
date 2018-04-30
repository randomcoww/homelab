## gateway
resource "matchbox_profile" "gateway_bootstrap" {
  name   = "gateway_bootstrap"
  container_linux_config = "${file("./ignition/gateway_bootstrap.yaml.tmpl")}"
}


## groups
resource "matchbox_group" "gateway_bootstrap" {
  name    = "gateway_bootstrap"
  profile = "${matchbox_profile.gateway_bootstrap.name}"

  selector {
    host = "gateway_bootstrap"
  }

  metadata {
    name        = "gateway_bootstrap.${var.internal_domain}"
    lan_ip      = "192.168.62.216"
    store_ip    = "192.168.126.216"
    sync_ip     = "192.168.190.216"
    netmask     = "23"
    gateway_ip  = "${var.gateway_ip}"
    dns_ip      = "${var.dns_ip}"
    default_user    = "${var.default_user}"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${tls_private_key.ssh.public_key_openssh}"
    manifest_url = "https://raw.githubusercontent.com/randomcoww/environment-config/master/manifests/gateway"
  }
}
