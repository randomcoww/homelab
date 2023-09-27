resource "ssh_user_cert" "ssh-client" {
  ca_private_key_pem    = data.terraform_remote_state.sr.outputs.ssh_ca.private_key_pem
  public_key_openssh    = var.ssh_client.public_key_openssh
  key_id                = var.ssh_client.key_id
  early_renewal_hours   = var.ssh_client.early_renewal_hours
  validity_period_hours = var.ssh_client.validity_period_hours
  valid_principals      = []
  extensions = [
    "permit-agent-forwarding",
    "permit-port-forwarding",
    "permit-pty",
    "permit-user-rc",
  ]
  critical_options = []
}