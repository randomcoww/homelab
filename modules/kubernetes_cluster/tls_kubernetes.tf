##
## matchbox
##
resource "tls_private_key" "kubernetes" {
  count = "${length(var.controller_hosts)}"

  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "kubernetes" {
  count = "${length(var.controller_hosts)}"

  key_algorithm   = "${element(tls_private_key.kubernetes.*.algorithm, count.index)}"
  private_key_pem = "${element(tls_private_key.kubernetes.*.private_key_pem, count.index)}"

  subject {
    common_name  = "kubernetes"
    organization = "kubernetes"
  }

  dns_names = [
    "kubernetes.default",
  ]

  ip_addresses = [
    "127.0.0.1",
    "${var.controller_ips[count.index]}",
    "${var.cluster_service_ip}",
    "${var.controller_vip}",
  ]
}

resource "tls_locally_signed_cert" "kubernetes" {
  count = "${length(var.controller_hosts)}"

  cert_request_pem   = "${element(tls_cert_request.kubernetes.*.cert_request_pem, count.index)}"
  ca_key_algorithm   = "${tls_private_key.root.algorithm}"
  ca_private_key_pem = "${tls_private_key.root.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.root.cert_pem}"

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}
