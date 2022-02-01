# SSH CA #
resource "tls_private_key" "ssh-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

# SSH client #
resource "ssh_client_cert" "ssh-client" {
  ca_key_algorithm      = tls_private_key.ssh-ca.algorithm
  ca_private_key_pem    = tls_private_key.ssh-ca.private_key_pem
  key_id                = var.ssh_client.key_id
  public_key_openssh    = var.ssh_client.public_key
  early_renewal_hours   = var.ssh_client.early_renewal_hours
  validity_period_hours = var.ssh_client.validity_period_hours
  valid_principals      = []

  extensions = [
    "permit-agent-forwarding",
    "permit-port-forwarding",
    "permit-pty",
    "permit-user-rc",
  ]
}