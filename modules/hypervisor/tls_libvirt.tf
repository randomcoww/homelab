## servercert and clientcert on hypervisors
## https://wiki.libvirt.org/page/TLSCreateClientCerts
resource "tls_private_key" "libvirt" {
  algorithm   = var.ca.libvirt.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "libvirt" {
  key_algorithm   = tls_private_key.libvirt.algorithm
  private_key_pem = tls_private_key.libvirt.private_key_pem

  subject {
    common_name = var.hostname
  }

  dns_names = [
    var.hostname,
  ]

  ip_addresses = concat(["127.0.0.1"], [
    for interface in values(local.interfaces) :
    [
      for tap in value(interface.taps) :
      tap.ip
    ]
  ])
}

resource "tls_locally_signed_cert" "libvirt" {
  cert_request_pem   = tls_cert_request.libvirt.cert_request_pem
  ca_key_algorithm   = var.ca.libvirt.algorithm
  ca_private_key_pem = var.ca.libvirt.private_key_pem
  ca_cert_pem        = var.ca.libvirt.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}