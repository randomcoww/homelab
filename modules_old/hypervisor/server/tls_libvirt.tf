## servercert and clientcert on hypervisors
## https://wiki.libvirt.org/page/TLSCreateClientCerts
resource "tls_private_key" "libvirt" {
  algorithm   = var.libvirt_ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "libvirt" {
  key_algorithm   = tls_private_key.libvirt.algorithm
  private_key_pem = tls_private_key.libvirt.private_key_pem

  subject {
    common_name = var.dns_names[0]
  }

  dns_names    = var.dns_names
  ip_addresses = var.ip_addresses
}

resource "tls_locally_signed_cert" "libvirt" {
  cert_request_pem   = tls_cert_request.libvirt.cert_request_pem
  ca_key_algorithm   = var.libvirt_ca.algorithm
  ca_private_key_pem = var.libvirt_ca.private_key_pem
  ca_cert_pem        = var.libvirt_ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}