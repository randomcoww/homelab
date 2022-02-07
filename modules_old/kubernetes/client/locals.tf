locals {
  certs = {
    client = {
      ca = {
        content = var.kubernetes_ca.cert_pem
      }
      cert = {
        content = tls_locally_signed_cert.admin.cert_pem
      }
      key = {
        content = tls_private_key.bootstrap.admin
      }
    }
  }
}