resource "tls_private_key" "ssh-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_private_key" "ssh-host" {
  algorithm   = var.ca.algorithm
  ecdsa_curve = "P521"
}

resource "ssh_host_cert" "ssh-host" {
  ca_private_key_pem    = var.ca.private_key_pem
  public_key_openssh    = tls_private_key.ssh-host.public_key_openssh
  key_id                = var.hostname
  early_renewal_hours   = var.early_renewal_hours
  validity_period_hours = var.validity_period_hours
  valid_principals      = concat(["127.0.0.1", var.hostname], var.node_ips)
  critical_options      = []
  extensions            = []
}