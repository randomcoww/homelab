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

    host_ip      = "${var.vm_ips[count.index]}"
    host_if      = "${var.vm_if}"
    host_netmask = "${var.vm_netmask}"
    ll_if        = "${var.ll_if}"
    ll_ip        = "${var.ll_ip}"
    ll_netmask   = "${var.ll_netmask}"
    mtu          = "${var.mtu}"

    container_linux_image_path = "${var.container_linux_image_path}"
    container_linux_base_url   = "${var.container_linux_base_url}"
    container_linux_version    = "${var.container_linux_version}"
  }
}
