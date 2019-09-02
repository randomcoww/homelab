##
## desktop kickstart renderer
## no PXE boot - provide ks endpoint only
##
resource "matchbox_profile" "generic_desktop" {
  name           = "host_desktop"
  generic_config = "${file("${path.module}/templates/kickstart/desktop.ks.tmpl")}"
}

locals {
  localhome_path = "/localhome"
}

resource "matchbox_group" "generic_desktop" {
  count = "${length(var.desktop_hosts)}"

  name    = "host_${var.desktop_hosts[count.index]}"
  profile = "${matchbox_profile.generic_desktop.name}"

  selector {
    ks = "${var.desktop_hosts[count.index]}"
  }

  metadata {
    hostname        = "${var.desktop_hosts[count.index]}"
    default_user    = "${var.default_user}"
    localhome_path  = "${local.localhome_path}"
    password        = "${var.password}"
    localhome_mount = "${join("-", compact(split("/", local.localhome_path)))}.mount"

    localhome_dev    = "/dev/disk/by-path/pci-0000:04:00.0-nvme-1-part1"
    store_macvlan_if = "int0"
    mtu              = "${var.mtu}"

    container_linux_image_path = "${var.container_linux_image_path}"
    container_linux_base_url   = "${var.container_linux_base_url}"
    container_linux_version    = "${var.container_linux_version}"
  }
}
