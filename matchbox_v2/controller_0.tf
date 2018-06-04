##
## vmhost kickstart renderer
##
resource "matchbox_profile" "controller_0" {
  name   = "controller_0"
  generic_config = "${file("./ignition/controller.tmpl")}"
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
    name         = "controller-0"
    default_user = "${var.default_user}"
    ssh_authorized_key          = "cert-authority ${chomp(tls_private_key.ssh_ca.public_key_openssh)}"
    service_account_private_key = "${chomp(tls_private_key.service_account.private_key)}"
    service_account_public_key  = "${chomp(tls_private_key.service_account.public_key)}"
  }
}
