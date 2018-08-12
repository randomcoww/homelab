##
## provisioner ignition renderer
##
resource "matchbox_profile" "ignition_provisioner" {
  name                   = "ignition_provisioner"
  container_linux_config = "${file("${path.module}/templates/ignition/provisioner.ign.tmpl")}"
}

resource "matchbox_group" "ignition_provisioner" {
  count = "${length(var.provisioner_hosts)}"

  name    = "ignition_${var.provisioner_hosts[count.index]}"
  profile = "${matchbox_profile.ignition_provisioner.name}"

  selector {
    host = "${var.provisioner_hosts[count.index]}"
  }

  metadata {
    hostname           = "${var.provisioner_hosts[count.index]}"
    hyperkube_image    = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${chomp(var.ssh_ca_public_key)}"
    default_user       = "${var.default_user}"
    manifest_url       = "${var.remote_provision_url}/manifest/${matchbox_profile.manifest_provisioner.name}.yaml"

    lan_ip        = "${var.provisioner_lan_ips[count.index]}"
    lan_if        = "${var.provisioner_lan_if}"
    lan_netmask   = "${var.lan_netmask}"
    store_ip      = "${var.provisioner_store_ips[count.index]}"
    store_if      = "${var.provisioner_store_if}"
    store_netmask = "${var.store_netmask}"
    wan_if        = "${var.provisioner_wan_if}"
    backup_dns_ip = "${var.backup_dns_ip}"

    matchbox_vip = "${var.matchbox_vip}"

    certs_path  = "${var.certs_path}"
    docker_opts = "--log-driver=journald --iptables=false"

    tls_ca           = "${replace(tls_self_signed_cert.root.cert_pem, "\n", "\\n")}"
    tls_matchbox     = "${replace(element(tls_locally_signed_cert.matchbox.*.cert_pem, count.index), "\n", "\\n")}"
    tls_matchbox_key = "${replace(element(tls_private_key.matchbox.*.private_key_pem, count.index), "\n", "\\n")}"
  }
}
