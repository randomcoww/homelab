##
## ssh ca key
##
resource "tls_private_key" "ssh_ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}
