output "manifest" {
  value     = join("\n---\n", values(local.manifests))
  sensitive = true
}

output "matchbox_endpoint" {
  value = "http://${local.listen_ip}:${local.ports.matchbox}"
}

output "matchbox_ca" {
  value = {
    algorithm       = tls_private_key.matchbox-ca.algorithm
    private_key_pem = tls_private_key.matchbox-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.matchbox-ca.cert_pem
  }
  sensitive = true
}

output "matchbox_client" {
  value = {
    algorithm       = tls_private_key.matchbox-client.algorithm
    private_key_pem = tls_private_key.matchbox-client.private_key_pem
    cert_pem        = tls_locally_signed_cert.matchbox-client.cert_pem
  }
  sensitive = true
}
