resource "local_file" "matchbox_ca_pem" {
  content  = "${chomp(tls_self_signed_cert.root.cert_pem)}"
  filename = "output/ca.crt"
}

resource "local_file" "matchbox_private_key_pem" {
  content  = "${chomp(tls_private_key.matchbox.private_key_pem)}"
  filename = "output/server.key"
}

resource "local_file" "matchbox_cert_pem" {
  content  = "${chomp(tls_locally_signed_cert.matchbox.cert_pem)}"
  filename = "output/server.crt"
}