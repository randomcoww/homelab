##
## kube controller kickstart renderer
##
resource "matchbox_profile" "controller_0" {
  name   = "controller_0"
  container_linux_config = "${file("./ignition/controller.ign.tmpl")}"
  kernel = "/assets/coreos/${var.container_linux_version}/coreos_production_pxe.vmlinuz"
  initrd = [
    "/assets/coreos/${var.container_linux_version}/coreos_production_pxe_image.cpio.gz"
  ]
  args = [
    "coreos.config.url=${var.matchbox_url}/ignition?mac=$${mac:hexhyp}",
    "coreos.first_boot=yes",
    "console=hvc0",
    "coreos.autologin"
  ]
}


##
## kickstart
##
resource "matchbox_group" "controller_0" {
  name    = "controller_0"
  profile = "${matchbox_profile.controller_0.name}"

  selector {
    mac = "52-54-00-1a-61-8b"
  }

  metadata {
    hostname      = "controller-0"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${chomp(tls_private_key.ssh_ca.public_key_openssh)}"
    default_user  = "${var.default_user}"
    hyperkube_image = "${var.hyperkube_image}"
    manifest_url  = "https://raw.githubusercontent.com/randomcoww/environment-config/master/manifests/controller-0"
    apiserver_url = "https://127.0.0.1:56443"

    ip_store      = "192.168.126.219"
    netmask_store = "23"

    tls_ca        = "${replace(tls_self_signed_cert.root.cert_pem, "\n", "\\n")}"
    tls_ca_key    = "${replace(tls_private_key.root.private_key_pem, "\n", "\\n")}"
    tls_kubernetes  = "${replace(tls_locally_signed_cert.kubernetes.cert_pem, "\n", "\\n")}"
    tls_kubernetes_key = "${replace(tls_private_key.kubernetes.private_key_pem, "\n", "\\n")}"
    tls_controller_manager  = "${replace(tls_locally_signed_cert.controller_manager.cert_pem, "\n", "\\n")}"
    tls_controller_manager_key = "${replace(tls_private_key.controller_manager.private_key_pem, "\n", "\\n")}"
    tls_scheduler  = "${replace(tls_locally_signed_cert.scheduler.cert_pem, "\n", "\\n")}"
    tls_scheduler_key = "${replace(tls_private_key.scheduler.private_key_pem, "\n", "\\n")}"
    tls_service_account = "${replace(tls_private_key.service_account.public_key_pem, "\n", "\\n")}"
    tls_service_account_key = "${replace(tls_private_key.service_account.private_key_pem, "\n", "\\n")}"
  }
}
