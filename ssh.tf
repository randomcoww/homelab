module "ssh-server-common" {
  source = "./modules/ssh_server_common"
}

# SSH client #
resource "ssh_client_cert" "ssh-client" {
  ca_key_algorithm      = module.ssh-server-common.ca.ssh.algorithm
  ca_private_key_pem    = module.ssh-server-common.ca.ssh.private_key_pem
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

output "ssh_client_cert_authorized_key" {
  value = ssh_client_cert.ssh-client.cert_authorized_key
}