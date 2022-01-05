resource "tls_private_key" "ssh-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_private_key" "ssh-host" {
  algorithm   = var.ca.ssh.algorithm
  ecdsa_curve = "P521"
}

resource "ssh_host_cert" "ssh-host" {
  ca_key_algorithm      = var.ca.ssh.algorithm
  ca_private_key_pem    = var.ca.ssh.private_key_pem
  public_key_openssh    = tls_private_key.ssh-host.public_key_openssh
  key_id                = var.key_id
  early_renewal_hours   = var.early_renewal_hours
  validity_period_hours = var.validity_period_hours
  valid_principals      = var.valid_principals
}