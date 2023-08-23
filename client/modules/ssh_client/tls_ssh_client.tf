resource "ssh_user_cert" "ssh-client" {
  ca_private_key_pem    = var.ca.private_key_pem
  public_key_openssh    = var.public_key_openssh
  key_id                = var.key_id
  early_renewal_hours   = var.early_renewal_hours
  validity_period_hours = var.validity_period_hours
  valid_principals      = var.valid_principals
  extensions = [
    "permit-agent-forwarding",
    "permit-port-forwarding",
    "permit-pty",
    "permit-user-rc",
  ]
  critical_options = []
}