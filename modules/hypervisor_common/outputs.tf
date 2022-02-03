output "ca" {
  value = {
    libvirt = {
      algorithm       = tls_private_key.libvirt-ca.algorithm
      private_key_pem = tls_private_key.libvirt-ca.private_key_pem
      cert_pem        = tls_self_signed_cert.libvirt-ca.cert_pem
    }
  }
}