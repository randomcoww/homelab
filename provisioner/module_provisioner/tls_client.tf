##
## matchbox client
##
resource "tls_private_key" "client" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "client" {
  key_algorithm   = "${tls_private_key.client.algorithm}"
  private_key_pem = "${tls_private_key.client.private_key_pem}"

  subject {
    common_name  = "client"
    organization = "client"
  }
}

resource "tls_locally_signed_cert" "client" {
  count = "${length(var.provisioner_hosts)}"

  cert_request_pem   = "${tls_cert_request.client.cert_request_pem}"
  ca_key_algorithm   = "${tls_private_key.root.algorithm}"
  ca_private_key_pem = "${tls_private_key.root.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.root.cert_pem}"

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "server_auth",
    "client_auth",
  ]
}

resource "local_file" "ca_pem" {
  content  = "${chomp(tls_self_signed_cert.root.cert_pem)}"
  filename = "output/${var.output_path}/ca.crt"
}

resource "local_file" "client_private_key_pem" {
  content  = "${chomp(tls_private_key.client.private_key_pem)}"
  filename = "output/${var.output_path}/client.key"
}

resource "local_file" "client_cert_pem" {
  content  = "${chomp(tls_locally_signed_cert.client.cert_pem)}"
  filename = "output/${var.output_path}/client.crt"
}
