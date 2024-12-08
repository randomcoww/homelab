# SSH client

module "client" {
  for_each = local.members.client
  source   = "./modules/client"

  ignition_version   = local.ignition_version
  public_key_openssh = data.terraform_remote_state.sr.outputs.ssh.ca.public_key_openssh
}