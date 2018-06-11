##
## kube controller kickstart renderer
##
resource "matchbox_profile" "controller_0" {
  name   = "controller_0"
  container_linux_config = "${file("./ignition/controller.ign.tmpl")}"
}


##
## kickstart
##
resource "matchbox_group" "controller_0" {
  name    = "controller_0"
  profile = "${matchbox_profile.controller_0.name}"

  selector {
    host = "controller_0"
  }

  metadata {
    hostname      = "controller-0.${var.internal_domain}"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${chomp(tls_private_key.ssh_ca.public_key_openssh)}"
    default_user  = "${var.default_user}"

    manifest_url  = "http://provisioner.svc.internal:58080/generic?manifest=controller"
    hyperkube_image = "gcr.io/google_containers/hyperkube:v1.10.3"
    tls_ca        = "${chomp(tls_self_signed_cert.root.cert_pem)}"
    tls_api_server  = "${chomp(tls_locally_signed_cert.api_server.cert_pem)}"
    tls_api_server_key = "${chomp(tls_private_key.api_server.private_key_pem)}"
    tls_service_account = "${chomp(tls_private_key.service_account.public_key_pem)}"
    tls_service_account_key = "${chomp(tls_private_key.service_account.private_key_pem)}"
  }
}
