resource "tls_private_key" "ssh-client" {
  algorithm   = data.terraform_remote_state.sr.outputs.ssh.ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = 4096
}

resource "ssh_user_cert" "ssh-client" {
  ca_private_key_pem    = data.terraform_remote_state.sr.outputs.ssh.ca.private_key_pem
  public_key_openssh    = tls_private_key.ssh-client.public_key_openssh
  key_id                = local.users.ssh.name
  early_renewal_hours   = 0
  validity_period_hours = 1
  valid_principals      = []
  extensions = [
    "permit-agent-forwarding",
    "permit-port-forwarding",
    "permit-pty",
    "permit-user-rc",
  ]
  critical_options = []
}