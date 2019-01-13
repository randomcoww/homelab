##
## vmhost kickstart renderer
##
resource "matchbox_profile" "generic_store" {
  name           = "host_store"
  generic_config = "${file("${path.module}/templates/kickstart/store.ks.tmpl")}"
}

resource "matchbox_group" "generic_store" {
  count = "${length(var.store_hosts)}"

  name    = "host_${var.store_hosts[count.index]}"
  profile = "${matchbox_profile.generic_store.name}"

  selector {
    ks = "${var.store_hosts[count.index]}"
  }

  metadata {
    ssh_authorized_key = "cert-authority ${chomp(var.ssh_ca_public_key)}"
    default_user       = "${var.default_user}"

    host_if  = "${var.store_if}"
    host_vif = "${var.store_vif}"
    mtu      = "${var.mtu}"
  }
}
