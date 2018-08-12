##
## live kickstart renderer
##
resource "matchbox_profile" "generic_live" {
  name           = "host_live"
  generic_config = "${file("${path.module}/templates/kickstart/live.ks.tmpl")}"
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

resource "matchbox_group" "generic_live" {
  count   = "${length(var.live_hosts)}"

  name    = "host_${var.live_hosts[count.index]}"
  profile = "${matchbox_profile.generic_live.name}"

  selector {
    mac = "${var.live_macs[count.index]}"
  }

  metadata {
    hostname           = "${var.live_hosts[count.index]}"
    hyperkube_image    = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${chomp(tls_private_key.ssh_ca.public_key_openssh)}"
    default_user       = "${var.default_user}"

    lan_ip        = "${var.live_lan_ips[count.index]}"
    lan_if        = "${var.live_lan_if}"
    lan_netmask   = "${var.lan_netmask}"
    store_ip      = "${var.live_store_ips[count.index]}"
    store_if      = "${var.live_store_if}"
    store_netmask = "${var.store_netmask}"
  }
}
