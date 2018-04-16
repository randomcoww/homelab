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


##
## vmhost kickstart renderer
##
resource "matchbox_profile" "vmhost_ks" {
  name   = "vmhost_ks"
  generic_config = "${file("./kickstart/vmhost.ks.tmpl")}"
}

resource "matchbox_profile" "vmhost_live_ks" {
  name   = "vmhost_live_ks"
  generic_config = "${file("./kickstart/vmhost_live.ks.tmpl")}"
}


##
## render cloud configs
##
resource "matchbox_profile" "vmhost_cloud" {
  name   = "vmhost_cloud"
  generic_config = "${file("./cloud/vmhost.yaml.tmpl")}"
}


##
## PXE live boot
##
resource "matchbox_profile" "vmhost_live" {
  name   = "vmhost_live"
  kernel = "/assets/fedora/vmlinuz-4.15.14-300.fc27.x86_64"
  initrd = [
    "/assets/fedora/initramfs-4.15.14-300.fc27.x86_64.img"
  ]
  args = [
    "root=live:${var.matchbox_http_endpoint}/assets/fedora/live-rootfs.squashfs.img",
    "console=tty0",
    "console=ttyS1,115200n8",
    "elevator=noop",
    "intel_iommu=on",
    "iommu=pt",
    "cgroup_enable=memory",
    "rd.writable.fsimg=1"
  ]
}


##
## kickstart
##
resource "matchbox_group" "vmhost_ks" {
  name    = "vmhost_ks"
  profile = "${matchbox_profile.vmhost_ks.name}"

  selector {
    host = "vmhost_ks"
  }

  metadata {
    name         = "vmhost_ks"
    default_user = "${var.default_user}"
  }
}

resource "matchbox_group" "vmhost_live_ks" {
  name    = "vmhost_live_ks"
  profile = "${matchbox_profile.vmhost_live_ks.name}"

  selector {
    host = "vmhost_live_ks"
  }

  metadata {
    name         = "vmhost_live_ks"
    default_user = "${var.default_user}"
  }
}


##
## cloud-config renderer
##
resource "matchbox_group" "vmhost1" {
  name    = "vmhost1"
  profile = "${matchbox_profile.vmhost_cloud.name}"

  selector {
    host = "vmhost1"
  }

  metadata {
    name        = "vmhost1.${var.internal_domain}"
    store_ip    = "192.168.126.251"
    netmask     = "23"
    gateway_ip  = "${var.gateway_ip}"
    dns_ip      = "192.168.126.244"
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
  profile = "${matchbox_profile.vmhost_cloud.name}"

  selector {
    host = "vmhost2"
  }

  metadata {
    name        = "vmhost2.${var.internal_domain}"
    store_ip    = "192.168.126.252"
    netmask     = "23"
    gateway_ip  = "${var.gateway_ip}"
    dns_ip      = "192.168.126.244"
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


##
## PXE live boot profile selector
##
resource "matchbox_group" "vmhost2_live" {
  name    = "vmhost2_live"
  profile = "${matchbox_profile.vmhost_live.name}"

  selector {
    # mac = "0c-c4-7a-da-b5-a0"
    mac = "00-1b-21-bc-67-c6"
  }
}
