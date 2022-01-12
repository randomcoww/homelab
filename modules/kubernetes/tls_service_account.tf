resource "tls_private_key" "service-account" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}