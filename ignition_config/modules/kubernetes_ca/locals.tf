locals {
  ca = {
    algorithm       = tls_private_key.kubernetes-ca.algorithm
    private_key_pem = tls_private_key.kubernetes-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.kubernetes-ca.cert_pem
  }

  certs = {
    ca_cert = {
      content = tls_self_signed_cert.kubernetes-ca.cert_pem
    }
    ca_key = {
      content = tls_private_key.kubernetes-ca.private_key_pem
    }
    service_account_cert = {
      content = tls_private_key.service-account.public_key_pem
    }
    service_account_key = {
      content = tls_private_key.service-account.private_key_pem
    }
  }
}

resource "random_string" "encryption-config-secret" {
  length  = 32
  special = false
}