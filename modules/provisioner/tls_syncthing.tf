##
## syncthing
##
resource "tls_private_key" "syncthing" {
  count = "${length(var.provisioner_hosts)}"

  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_cert_request" "syncthing" {
  count = "${length(var.provisioner_hosts)}"

  key_algorithm   = "${element(tls_private_key.syncthing.*.algorithm, count.index)}"
  private_key_pem = "${element(tls_private_key.syncthing.*.private_key_pem, count.index)}"

  subject {
    common_name = "syncthing"
  }
}

resource "tls_locally_signed_cert" "syncthing" {
  count = "${length(var.provisioner_hosts)}"

  cert_request_pem   = "${element(tls_cert_request.syncthing.*.cert_request_pem, count.index)}"
  ca_key_algorithm   = "${tls_private_key.root.algorithm}"
  ca_private_key_pem = "${tls_private_key.root.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.root.cert_pem}"

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

data "syncthing_device" "syncthing" {
  count = "${length(var.provisioner_hosts)}"

  cert_pem        = "${element(tls_locally_signed_cert.syncthing.*.cert_pem, count.index)}"
  private_key_pem = "${element(tls_private_key.syncthing.*.private_key_pem, count.index)}"
}
