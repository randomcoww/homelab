##
## vmhost kickstart renderer
##
resource "matchbox_profile" "provisioner_0" {
  name   = "provisioner_0"
  generic_config = "${file("./ignition/provisioner.ign.tmpl")}"
}


##
## kickstart
##
resource "matchbox_group" "provisioner_0" {
  name    = "provisioner_0"
  profile = "${matchbox_profile.provisioner_0.name}"

  selector {
    host = "provisioner_0"
  }

  metadata {
    hostname      = "provisioner-0.${var.internal_domain}"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${chomp(tls_private_key.ssh_ca.public_key_openssh)}"
    default_user  = "${var.default_user}"
    manifest_url  = "https://raw.githubusercontent.com/randomcoww/environment-config/master/manifests/provisioner"

    ip_lan        = "192.168.62.217"
    netmask_lan   = "23"
    ip_store      = "192.168.126.217"
    netmask_store = "23"
    ip_sync       = "192.168.190.217"
    netmask_sync  = "23"

    tls_ca        = "${replace(tls_self_signed_cert.kubernetes.cert_pem, "\n", "\\n")}"
    tls_ca_key    = "${replace(tls_private_key.kubernetes.private_key, "\n", "\\n")}"
    tls_matchbox  = "${replace(tls_locally_signed_cert.matchbox.cert_pem, "\n", "\\n")}"
    tls_matchbox_key = "${replace(tls_locally_signed_cert.matchbox.private_key, "\n", "\\n")}"
    tls_cfssl     = "${replace(tls_locally_signed_cert.cfssl.cert_pem, "\n", "\\n")}"
    tls_cfssl_key = "${replace(tls_locally_signed_cert.cfssl.private_key, "\n", "\\n")}"
  }
}
