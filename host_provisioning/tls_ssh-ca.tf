resource "tls_private_key" "ssh-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

output "ssh_ca" {
  value = {
    algorithm          = tls_private_key.ssh-ca.algorithm
    private_key_pem    = tls_private_key.ssh-ca.private_key_pem
    public_key_openssh = tls_private_key.ssh-ca.public_key_openssh
  }
  sensitive = true
}