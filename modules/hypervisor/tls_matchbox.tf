resource "tls_private_key" "matchbox" {
  algorithm   = var.matchbox_ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "matchbox" {
  key_algorithm   = tls_private_key.matchbox.algorithm
  private_key_pem = tls_private_key.matchbox.private_key_pem

  subject {
    common_name  = "matchbox"
    organization = "matchbox"
  }

  dns_names = [
    var.hostname,
  ]

  ip_addresses = compact(concat(["127.0.0.1"], flatten([
    for hardware_interface in values(local.hardware_interfaces) :
    [
      for interface in values(hardware_interface.interfaces) :
      try(cidrhost(interface.prefix, hardware_interface.netnum), null)
    ]
  ])))
}

resource "tls_locally_signed_cert" "matchbox" {
  cert_request_pem   = tls_cert_request.matchbox.cert_request_pem
  ca_key_algorithm   = var.matchbox_ca.algorithm
  ca_private_key_pem = var.matchbox_ca.private_key_pem
  ca_cert_pem        = var.matchbox_ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}