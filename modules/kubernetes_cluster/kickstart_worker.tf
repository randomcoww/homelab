##
## vmhost kickstart renderer
##
resource "matchbox_profile" "generic_worker" {
  name           = "host_worker"
  generic_config = "${file("${path.module}/templates/kickstart/worker.ks.tmpl")}"
}

resource "matchbox_group" "generic_worker" {
  name    = "host_worker"
  profile = "${matchbox_profile.generic_worker.name}"

  selector {
    ks = "kubernetes-worker"
  }

  metadata {
    apiserver_url = "https://${var.controller_vip}:${var.apiserver_secure_port}"

    cluster_cidr   = "${var.cluster_cidr}"
    cluster_dns_ip = "${var.cluster_dns_ip}"
    cluster_domain = "${var.cluster_domain}"
    cluster_name   = "${var.cluster_name}"
    kubelet_path   = "${var.kubelet_path}"

    tls_ca            = "${tls_self_signed_cert.kubernetes_ca.cert_pem}"
    tls_bootstrap     = "${tls_locally_signed_cert.bootstrap.cert_pem}"
    tls_bootstrap_key = "${tls_private_key.bootstrap.private_key_pem}"
  }
}
