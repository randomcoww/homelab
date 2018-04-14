## profile
# resource "matchbox_profile" "ns" {
#   name   = "ns"
#   container_linux_config = "${file("./ignition/ns.yaml.tmpl")}"
# }

resource "matchbox_profile" "ns" {
  name   = "ns"
  container_linux_config = "${file("./ignition/ns.yaml.tmpl")}"
  kernel = "/assets/coreos/${var.container_linux_version}/coreos_production_pxe.vmlinuz"
  initrd = [
    "/assets/coreos/${var.container_linux_version}/coreos_production_pxe_image.cpio.gz"
  ]
  args = [
    "ip=192.168.126.255:::255.255.254.0::eth1:none:",
    "coreos.config.url=${var.matchbox_http_endpoint}/ignition?mac=$${mac:hexhyp}",
    "coreos.first_boot=yes",
    "console=hvc0",
    "coreos.autologin"
  ]
}


## groups
resource "matchbox_group" "ns1" {
  name    = "ns1"
  profile = "${matchbox_profile.ns.name}"

  selector {
    # host = "ns1"
    mac = "52-54-00-44-b0-10"
  }

  metadata {
    name        = "ns1.${var.internal_domain}"
    lan_ip      = "192.168.62.219"
    store_ip    = "192.168.126.219"
    netmask     = "23"
    gateway_ip  = "${var.gateway_ip}"
    dns_ip      = "127.0.0.1"
    default_user   = "${var.default_user}"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${tls_private_key.ssh.public_key_openssh}"
    manifest_url = "https://raw.githubusercontent.com/randomcoww/environment-config/master/manifests/ns1"
  }
}

resource "matchbox_group" "ns2" {
  name    = "ns2"
  profile = "${matchbox_profile.ns.name}"

  selector {
    # host = "ns2"
    mac = "52-54-00-44-b0-11"
  }

  metadata {
    name        = "ns2.${var.internal_domain}"
    lan_ip      = "192.168.62.220"
    store_ip    = "192.168.126.220"
    netmask     = "23"
    gateway_ip  = "${var.gateway_ip}"
    dns_ip      = "127.0.0.1"
    default_user   = "${var.default_user}"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${tls_private_key.ssh.public_key_openssh}"
    manifest_url = "https://raw.githubusercontent.com/randomcoww/environment-config/master/manifests/ns2"
  }
}

resource "matchbox_group" "ns3" {
  name    = "ns3"
  profile = "${matchbox_profile.ns.name}"

  selector {
    # host = "ns3"
    mac = "52-54-00-44-b0-12"
  }

  metadata {
    name        = "ns3.${var.internal_domain}"
    lan_ip      = "192.168.62.221"
    store_ip    = "192.168.126.221"
    netmask     = "23"
    gateway_ip  = "${var.gateway_ip}"
    dns_ip      = "127.0.0.1"
    default_user   = "${var.default_user}"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${tls_private_key.ssh.public_key_openssh}"
    manifest_url = "https://raw.githubusercontent.com/randomcoww/environment-config/master/manifests/ns3"
  }
}
