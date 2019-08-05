##
## desktop kickstart renderer
## no PXE boot - provide ks endpoint only
##
resource "matchbox_profile" "generic_desktop" {
  name           = "host_desktop"
  generic_config = "${file("${path.module}/templates/kickstart/desktop.ks.tmpl")}"
}

resource "matchbox_group" "generic_desktop" {
  count = "${length(var.desktop_hosts)}"

  name    = "host_${var.desktop_hosts[count.index]}"
  profile = "${matchbox_profile.generic_desktop.name}"

  selector {
    ks = "${var.desktop_hosts[count.index]}"
  }

  metadata {
    hostname       = "${var.desktop_hosts[count.index]}"
    default_user   = "${var.default_user}"
    localhome_path = "/localhome"
    password       = "${var.password}"

    store_macvlan_if = "int0"
    mtu              = "${var.mtu}"

    container_linux_image_path = "${var.container_linux_image_path}"
    container_linux_base_url   = "${var.container_linux_base_url}"
    container_linux_version    = "${var.container_linux_version}"
  }
}
