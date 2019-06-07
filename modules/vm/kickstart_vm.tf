##
## vmhost kickstart renderer
##
resource "matchbox_profile" "generic_vm" {
  name           = "host_vm"
  generic_config = "${file("${path.module}/templates/kickstart/vm.ks.tmpl")}"
}

resource "matchbox_group" "generic_vm" {
  count = "${length(var.vm_hosts)}"

  name    = "host_${var.vm_hosts[count.index]}"
  profile = "${matchbox_profile.generic_vm.name}"

  selector {
    ks = "${var.vm_hosts[count.index]}"
  }

  metadata {
    hostname           = "${var.vm_hosts[count.index]}"
    ssh_authorized_key = "cert-authority ${chomp(var.ssh_ca_public_key)}"
    default_user       = "${var.default_user}"
    password           = "${var.password}"

    store_ip         = "${var.vm_store_ips[count.index]}"
    store_if         = "${var.vm_store_ifs[count.index]}"
    store_netmask    = "${var.store_netmask}"
    store_macvlan_if = "int0"
    lan_if           = "en${var.vm_lan_if}"
    sync_if          = "en${var.vm_sync_if}"
    wan_if           = "en${var.vm_wan_if}"
    mtu              = "${var.mtu}"

    container_linux_image_path = "${var.container_linux_image_path}"
    container_linux_base_url   = "${var.container_linux_base_url}"
    container_linux_version    = "${var.container_linux_version}"
  }
}
