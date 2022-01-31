output "manifests" {
  value = local.manifests
}

output "ca" {
  value = {
    matchbox = {
      algorithm       = tls_private_key.matchbox-ca.algorithm
      private_key_pem = tls_private_key.matchbox-ca.private_key_pem
      cert_pem        = tls_self_signed_cert.matchbox-ca.cert_pem
    }
  }
}