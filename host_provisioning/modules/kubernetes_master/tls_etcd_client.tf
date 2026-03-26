# client #
resource "tls_private_key" "kube-apiserver-etcd-client" {
  algorithm   = var.etcd_ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "kube-apiserver-etcd-client" {
  private_key_pem = tls_private_key.kube-apiserver-etcd-client.private_key_pem

  subject {
    common_name = "kube-apiserver-etcd-client"
  }
}

resource "tls_locally_signed_cert" "kube-apiserver-etcd-client" {
  cert_request_pem   = tls_cert_request.kube-apiserver-etcd-client.cert_request_pem
  ca_private_key_pem = var.etcd_ca.private_key_pem
  ca_cert_pem        = var.etcd_ca.cert_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}