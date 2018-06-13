resource "local_file" "tls_ca" {
  content  = "${chomp(tls_self_signed_cert.root.cert_pem)}"
  filename = "output/ca.pem"
}

resource "local_file" "tls_key" {
  content  = "${chomp(tls_private_key.admin.private_key_pem)}"
  filename = "output/admin-key.pem"
}

resource "local_file" "tls_cert" {
  content  = "${chomp(tls_locally_signed_cert.admin.cert_pem)}"
  filename = "output/admin.pem"
}

## ssh ca
resource "local_file" "ssh_ca_key" {
  content  = "${chomp(tls_private_key.ssh_ca.private_key_pem)}"
  filename = "output/ssh-ca-key.pem"
}
