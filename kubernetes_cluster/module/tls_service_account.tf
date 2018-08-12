##
## tls private public key
##
resource "tls_private_key" "service_account" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}
