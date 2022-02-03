output "ca" {
  value = {
    ssh = {
      algorithm          = tls_private_key.ssh-ca.algorithm
      private_key_pem    = tls_private_key.ssh-ca.private_key_pem
      public_key_openssh = tls_private_key.ssh-ca.public_key_openssh
    }
  }
}