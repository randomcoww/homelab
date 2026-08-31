resource "tls_private_key" "ssh-client" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "ssh_user_cert" "ssh-client" {
  ca_private_key_pem    = var.ssh_ca.private_key_pem
  public_key_openssh    = tls_private_key.ssh-client.public_key_openssh
  key_id                = var.ssh_user
  early_renewal_hours   = 2160
  validity_period_hours = 8760
  valid_principals      = [var.ssh_user]
  extensions = {
    "permit-agent-forwarding" = ""
    "permit-port-forwarding"  = ""
    "permit-pty"              = ""
    "permit-user-rc"          = ""
  }
  critical_options = {}
}