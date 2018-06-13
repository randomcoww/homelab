##
## kube worker kickstart renderer
##
resource "matchbox_profile" "worker_0" {
  name   = "worker_0"
  container_linux_config = "${file("./ignition/worker.ign.tmpl")}"
  kernel = "/assets/coreos/${var.container_linux_version}/coreos_production_pxe.vmlinuz"
  initrd = [
    "/assets/coreos/${var.container_linux_version}/coreos_production_pxe_image.cpio.gz"
  ]
  args = [
    "coreos.config.url=http://${var.matchbox_ip}:58080/ignition?mac=$${mac:hexhyp}",
    "coreos.first_boot=yes",
    "console=hvc0",
    "coreos.autologin"
  ]
}


##
## kickstart
##
resource "matchbox_group" "worker_0" {
  name    = "worker_0"
  profile = "${matchbox_profile.worker_0.name}"

  selector {
    mac = "52-54-00-1a-61-8c"
  }

  metadata {
    hostname      = "worker-0"
    hyperkube_image = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${chomp(tls_private_key.ssh_ca.public_key_openssh)}"
    default_user  = "${var.default_user}"
    manifest_url  = "https://raw.githubusercontent.com/randomcoww/environment-config/master/manifests/worker-0"
    hyperkube_image = "gcr.io/google_containers/hyperkube:v1.10.3"

    tls_ca        = "${replace(tls_self_signed_cert.root.cert_pem, "\n", "\\n")}"

    tls_kubelet   = "${replace(tls_locally_signed_cert.kubelet.cert_pem, "\n", "\\n")}"
    tls_kubelet_key = "${replace(tls_private_key.kubelet.private_key_pem, "\n", "\\n")}"
    tls_proxy     = "${replace(tls_locally_signed_cert.proxy.cert_pem, "\n", "\\n")}"
    tls_proxy_key = "${replace(tls_private_key.proxy.private_key_pem, "\n", "\\n")}"
  }
}
