## write certs locally
resource "local_file" "ca" {
  content  = "${chomp(tls_self_signed_cert.root.cert_pem)}"
  filename = "/tmp/internal-ca.pem"
}


module "local_cert" {
  source = "../modules/cert"
  common_name = "vmhost1"
  ca_key_algorithm   = "${tls_private_key.root.algorithm}"
  ca_private_key_pem = "${tls_private_key.root.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.root.cert_pem}"
  ip_addresses = [
    "127.0.0.1",
    "192.168.62.251",
    "192.168.126.251"
  ]
  dns_names = [
    "*.svc.internal",
    "*.host.internal"
  ]
}


resource "local_file" "key" {
  content  = "${chomp(module.local_cert.private_key_pem)}"
  filename = "/tmp/internal-key.pem"
}

resource "local_file" "cert" {
  content  = "${chomp(module.local_cert.cert_pem)}"
  filename = "/tmp/internal.pem"
}
