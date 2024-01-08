resource "tls_private_key" "apiserver" {
  algorithm   = var.ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "apiserver" {
  private_key_pem = tls_private_key.apiserver.private_key_pem

  subject {
    common_name = "kube-apiserver"
  }

  ip_addresses = concat(["127.0.0.1"], var.apiserver_listen_ips)
  dns_names = [
    for i, _ in split(".", var.cluster_apiserver_endpoint) :
    join(".", slice(split(".", var.cluster_apiserver_endpoint), 0, i + 1))
  ]
}

resource "tls_locally_signed_cert" "apiserver" {
  cert_request_pem   = tls_cert_request.apiserver.cert_request_pem
  ca_private_key_pem = var.ca.private_key_pem
  ca_cert_pem        = var.ca.cert_pem

  validity_period_hours = 8760

  # Add both server and client here
  # This is reused for kubelet-client
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}