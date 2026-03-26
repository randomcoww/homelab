resource "tls_private_key" "kube-apiserver-kubelet-client" {
  algorithm   = var.kubernetes_ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "kube-apiserver-kubelet-client" {
  private_key_pem = tls_private_key.kube-apiserver-kubelet-client.private_key_pem

  subject {
    common_name = var.kubelet_client_user
  }
}

resource "tls_locally_signed_cert" "kube-apiserver-kubelet-client" {
  cert_request_pem   = tls_cert_request.kube-apiserver-kubelet-client.cert_request_pem
  ca_private_key_pem = var.kubernetes_ca.private_key_pem
  ca_cert_pem        = var.kubernetes_ca.cert_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}