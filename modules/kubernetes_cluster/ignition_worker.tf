##
## kube worker igntiion renderer
##
resource "matchbox_profile" "ignition_worker" {
  name                   = "host_worker"
  container_linux_config = "${file("${path.module}/templates/ignition/worker.ign.tmpl")}"
  kernel                 = "${var.container_linux_base_url}/${var.container_linux_version}/coreos_production_pxe.vmlinuz"

  initrd = [
    "${var.container_linux_base_url}/${var.container_linux_version}/coreos_production_pxe_image.cpio.gz"
  ]

  args = [
    "coreos.config.url=http://${var.matchbox_vip}:${var.matchbox_http_port}/ignition?mac=$${mac:hexhyp}",
    "coreos.first_boot=yes",
    "console=hvc0",
    "coreos.autologin=hvc0"
  ]
}

resource "matchbox_group" "ignition_worker" {
  count = "${length(var.worker_hosts)}"

  name    = "host_${var.worker_hosts[count.index]}"
  profile = "${matchbox_profile.ignition_worker.name}"

  selector {
    mac = "${var.worker_macs[count.index]}"
  }

  metadata {
    hyperkube_image    = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${chomp(var.ssh_ca_public_key)}"
    default_user       = "${var.default_user}"
    apiserver_url      = "https://${var.controller_vip}:${var.apiserver_secure_port}"

    cluster_cidr   = "${var.cluster_cidr}"
    cluster_dns_ip = "${var.cluster_dns_ip}"
    cluster_domain = "${var.cluster_domain}"
    cluster_name   = "${var.cluster_name}"

    kubelet_path = "${var.kubelet_path}"

    tls_ca            = "${replace(tls_self_signed_cert.root.cert_pem, "\n", "\\n")}"
    tls_bootstrap     = "${replace(tls_locally_signed_cert.bootstrap.cert_pem, "\n", "\\n")}"
    tls_bootstrap_key = "${replace(tls_private_key.bootstrap.private_key_pem, "\n", "\\n")}"
  }
}
