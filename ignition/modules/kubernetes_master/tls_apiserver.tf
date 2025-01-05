resource "tls_private_key" "kube-apiserver" {
  algorithm   = var.kubernetes_ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "kube-apiserver" {
  private_key_pem = tls_private_key.kube-apiserver.private_key_pem

  subject {
    common_name = "kube-apiserver"
  }

  ip_addresses = [
    "127.0.0.1",
    var.node_ip,
    var.apiserver_ip,
    var.cluster_apiserver_ip,
  ]
  dns_names = [
    for i, _ in split(".", var.cluster_apiserver_endpoint) :
    join(".", slice(split(".", var.cluster_apiserver_endpoint), 0, i + 1))
  ]
}

resource "tls_locally_signed_cert" "kube-apiserver" {
  cert_request_pem   = tls_cert_request.kube-apiserver.cert_request_pem
  ca_private_key_pem = var.kubernetes_ca.private_key_pem
  ca_cert_pem        = var.kubernetes_ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}