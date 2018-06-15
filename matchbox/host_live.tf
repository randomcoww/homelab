##
## live kickstart renderer
##
resource "matchbox_profile" "live_0" {
  name   = "live_0"
  generic_config = "${file("./kickstart/live.ks.tmpl")}"
  kernel = "/assets/live_0/vmlinuz-4.15.14-300.fc27.x86_64"
  initrd = [
    "/assets/live_0/initramfs-4.15.14-300.fc27.x86_64.img"
  ]
  args = [
    "root=live:${var.matchbox_http_endpoint}/assets/live_0/live-rootfs.squashfs.img",
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
resource "matchbox_group" "live_0" {
  name    = "live_0"
  profile = "${matchbox_profile.live_0.name}"

  selector {
    mac = "00-1b-21-bc-67-c6"
  }

  metadata {
    hostname      = "live-0"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${chomp(tls_private_key.ssh_ca.public_key_openssh)}"
    default_user  = "${var.default_user}"

    ip_lan        = "192.168.62.252"
    if_lan        = "ens1f1"
    netmask_lan   = "23"
    ip_store      = "192.168.126.252"
    if_store      = "ens1f0"
    netmask_store = "23"
  }
}
