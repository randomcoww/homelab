## write certs locally
module "local_cert" {
  source = "../modules/cert"
  common_name = "local_cert"
  ca_key_algorithm   = "${tls_private_key.root.algorithm}"
  ca_private_key_pem = "${tls_private_key.root.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.root.cert_pem}"
}

resource "local_file" "ca" {
  content  = "${chomp(tls_self_signed_cert.root.cert_pem)}"
  filename = "/etc/ssl/certs/internal-ca.pem"
}

resource "local_file" "key" {
  content  = "${chomp(module.local_cert.private_key_pem)}"
  filename = "/etc/ssl/certs/internal-key.pem"
}

resource "local_file" "cert" {
  content  = "${chomp(module.local_cert.cert_pem)}"
  filename = "/etc/ssl/certs/internal.pem"
}
