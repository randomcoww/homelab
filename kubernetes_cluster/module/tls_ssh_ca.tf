##
## ssh ca key for kubernetes nodes
##
resource "tls_private_key" "ssh_ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}