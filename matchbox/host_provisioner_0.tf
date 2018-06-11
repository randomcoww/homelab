##
## gateway kickstart renderer
##
resource "matchbox_profile" "provisioner_0" {
  name   = "provisioner_0"
  container_linux_config = "${file("./ignition/provisioner.ign.tmpl")}"
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
    manifest_url  = "https://github.com/randomcoww/environment-config/blob/master/manifests/provisioner-0"
    hyperkube_image = "gcr.io/google_containers/hyperkube:v1.10.3"

    ip_lan        = "192.168.62.218"
    netmask_lan   = "23"
    ip_store      = "192.168.126.218"
    netmask_store = "23"
    ip_sync       = "192.168.190.218"
    netmask_sync  = "23"

    tls_ca        = "${chomp(tls_self_signed_cert.root.cert_pem)}"
    tls_matchbox  = "${chomp(tls_locally_signed_cert.matchbox.cert_pem)}"
    tls_matchbox_key = "${chomp(tls_private_key.matchbox.private_key_pem)}"
  }
}
