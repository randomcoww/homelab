##
## ssh ca key for provisioner nodes
##
resource "tls_private_key" "ssh_ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}