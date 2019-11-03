##
## SSH CA for all hosts
##
resource "tls_private_key" "ssh-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

## ssh ca
resource "local_file" "ssh-ca-key" {
  content  = chomp(tls_private_key.ssh-ca.private_key_pem)
  filename = "output/ssh-ca-key.pem"
}
