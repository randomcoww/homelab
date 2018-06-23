##
## gateway kickstart renderer
##
resource "matchbox_profile" "ignition_provisioner" {
  name                   = "ignition_provisioner"
  container_linux_config = "${file("./ignition/provisioner.ign.tmpl")}"
}

##
## kickstart
##
resource "matchbox_group" "ignition_provisioner_0" {
  name    = "ignition_provisioner_0"
  profile = "${matchbox_profile.ignition_provisioner.name}"

  selector {
    host = "provisioner-0"
  }

  metadata {
    hostname           = "provisioner-0"
    hyperkube_image    = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${chomp(tls_private_key.ssh_ca.public_key_openssh)}"
    default_user       = "${var.default_user}"
    manifest_url       = "https://raw.githubusercontent.com/randomcoww/environment-config/master/manifests/provisioner"

    lan_ip        = "192.168.62.217"
    lan_if        = "eth0"
    lan_netmask   = "${var.lan_netmask}"
    store_ip      = "192.168.126.217"
    store_if      = "eth1"
    store_netmask = "${var.store_netmask}"
    wan_if        = "eth2"
    dns_vip       = "8.8.8.8"

    docker_opts = "--log-driver=journald --iptables=false"

    tls_ca           = "${replace(tls_self_signed_cert.root.cert_pem, "\n", "\\n")}"
    tls_matchbox     = "${replace(tls_locally_signed_cert.matchbox.cert_pem, "\n", "\\n")}"
    tls_matchbox_key = "${replace(tls_private_key.matchbox.private_key_pem, "\n", "\\n")}"
  }
}
