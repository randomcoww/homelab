module "controller_cert" {
  source = "../modules/cert"
  common_name = "controller"
  ca_key_algorithm   = "${tls_private_key.root.algorithm}"
  ca_private_key_pem = "${tls_private_key.root.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.root.cert_pem}"
  ip_addresses = [
    "127.0.0.1"
  ]
  dns_names = [
    "*.svc.internal"
  ]
}

resource "matchbox_group" "controller" {
  name    = "controller"
  profile = "${matchbox_profile.controller.name}"

  selector {
    host = "controller"
  }

  metadata {
    name        = "controller"
    default_user    = "${var.default_user}"
    cluster_dns_ip  = "${var.cluster_dns_ip}"
    cluster_domain  = "${var.cluster_domain}"
    hyperkube_image = "${var.hyperkube_image}"

    ssh_authorized_key = "cert-authority ${tls_private_key.root.public_key_openssh}"
    # ssh_authorized_key = "${var.ssh_authorized_key}"
    internal_ca   = "${replace(tls_self_signed_cert.root.cert_pem, "\n", "\\n")}"
    internal_key  = "${replace(module.controller_cert.private_key_pem, "\n", "\\n")}"
    internal_cert = "${replace(module.controller_cert.cert_pem, "\n", "\\n")}"

    flannel_conf = "${replace(var.flannel_conf, "\n", "")}"
    cni_conf     = "${replace(var.cni_conf, "\n", "")}"
    kubeconfig   = "${replace(var.kubeconfig_local, "\n", "\\n")}"

    cert_base_path = "/etc/ssl/certs/internal"
  }
}
