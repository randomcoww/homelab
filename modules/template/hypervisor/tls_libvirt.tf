## servercert and clientcert on hypervisors
## https://wiki.libvirt.org/page/TLSCreateClientCerts

resource "tls_private_key" "libvirt" {
  for_each = var.hosts

  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "libvirt" {
  for_each = var.hosts

  key_algorithm   = tls_private_key.libvirt[each.key].algorithm
  private_key_pem = tls_private_key.libvirt[each.key].private_key_pem

  subject {
    common_name = each.value.hostname
  }

  dns_names = [
    each.value.hostname,
  ]

  ip_addresses = compact([
    "127.0.0.1",
    lookup(each.value.networks_by_key.internal, "ip", null),
  ])
}

resource "tls_locally_signed_cert" "libvirt" {
  for_each = var.hosts

  cert_request_pem   = tls_cert_request.libvirt[each.key].cert_request_pem
  ca_key_algorithm   = tls_private_key.libvirt-ca.algorithm
  ca_private_key_pem = tls_private_key.libvirt-ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.libvirt-ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}