##
## live kickstart renderer
##
resource "matchbox_profile" "generic_live" {
  name           = "host_live"
  generic_config = "${file("./kickstart/live.ks.tmpl")}"
  kernel         = "/assets/live/vmlinuz-${var.fedora_live_version}"

  initrd = [
    "/assets/live/initramfs-${var.fedora_live_version}.img",
  ]

  args = [
    "root=live:http://${var.matchbox_vip}:${var.matchbox_http_port}/assets/live/live-rootfs.squashfs.img",
    "console=tty0",
    "console=ttyS1,115200n8",
    "elevator=noop",
    "intel_iommu=on",
    "iommu=pt",
    "cgroup_enable=memory",
    "rd.writable.fsimg=1",
  ]
}

##
## kickstart
##
resource "matchbox_group" "generic_live" {
  name    = "host_live"
  profile = "${matchbox_profile.generic_live.name}"

  selector {
    mac = "00-1b-21-bc-67-c6"
  }

  metadata {
    hostname           = "live"
    hyperkube_image    = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${chomp(tls_private_key.ssh_ca.public_key_openssh)}"
    default_user       = "${var.default_user}"

    lan_ip        = "192.168.62.252"
    lan_if        = "ens1f1"
    lan_netmask   = "${var.lan_netmask}"
    store_ip      = "192.168.126.252"
    store_if      = "ens1f0"
    store_netmask = "${var.store_netmask}"
  }
}
