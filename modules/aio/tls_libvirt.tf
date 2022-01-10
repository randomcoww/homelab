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
    common_name = var.hostname
  }

  dns_names = [
    var.hostname,
  ]

  ip_addresses = concat(["127.0.0.1"], [
    for tap_interface in values(local.tap_interfaces) :
    cidrhost(tap_interface.prefix, var.netnums.host)
    if lookup(tap_interface, "enable_netnum", false)
    ], [
    for tap_interface in values(local.tap_interfaces) :
    cidrhost(tap_interface.prefix, var.netnums.vrrp)
    if lookup(tap_interface, "enable_vrrp_netnum", false)
  ])
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