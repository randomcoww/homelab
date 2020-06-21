##
## matchbox
##
resource "tls_private_key" "kubernetes" {
  for_each = var.controller_hosts

  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "kubernetes" {
  for_each = var.controller_hosts

  key_algorithm   = tls_private_key.kubernetes[each.key].algorithm
  private_key_pem = tls_private_key.kubernetes[each.key].private_key_pem

  subject {
    common_name  = "kubernetes"
    organization = "kubernetes"
  }

  dns_names = [
    "kubernetes.default",
    each.value.hostname,
  ]

  ip_addresses = compact([
    "127.0.0.1",
    lookup(each.value.networks_by_key.main, "ip", null),
    var.services.kubernetes_service.vip,
    var.services.kubernetes_apiserver.vip,
  ])
}

resource "tls_locally_signed_cert" "kubernetes" {
  for_each = var.controller_hosts

  cert_request_pem   = tls_cert_request.kubernetes[each.key].cert_request_pem
  ca_key_algorithm   = tls_private_key.kubernetes-ca.algorithm
  ca_private_key_pem = tls_private_key.kubernetes-ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.kubernetes-ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}
