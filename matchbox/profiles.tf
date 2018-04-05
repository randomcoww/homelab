resource "matchbox_profile" "ns" {
  name   = "ns"
  container_linux_config = "${file("./ignition/ns.yaml.tmpl")}"
}

resource "matchbox_profile" "gateway" {
  name   = "gateway"
  container_linux_config = "${file("./ignition/gateway.yaml.tmpl")}"
}


##
## controller ignition renderer
##
resource "matchbox_profile" "controller" {
  name   = "controller"
  container_linux_config = "${file("./ignition/controller.yaml.tmpl")}"
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


##
## vmhost common kickstart renderer
##
resource "matchbox_profile" "vmhost_ks" {
  name   = "vmhost_ks"
  generic_config = "${file("./kickstart/vmhost.ks.tmpl")}"
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
  kernel = "/assets/fedora/vmlinuz-4.15.13-300.fc27.x86_64"
  initrd = [
    "/assets/fedora/initramfs-4.15.13-300.fc27.x86_64.img"
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
