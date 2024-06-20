# Server including SSH

module "server" {
  for_each = local.members.server
  source   = "./modules/server"

  ignition_version = local.ignition_version
  key_id           = each.value.hostname
  valid_principals = sort(concat([
    for _, network in each.value.networks :
    cidrhost(network.prefix, each.value.netnum)
    if lookup(network, "enable_netnum", false)
    ], [
    each.value.hostname,
    each.value.tailscale_hostname,
    "127.0.0.1",
  ]))
  ca = data.terraform_remote_state.sr.outputs.ssh.ca
}

# SSH client

module "client" {
  for_each = local.members.client
  source   = "./modules/client"

  ignition_version   = local.ignition_version
  public_key_openssh = data.terraform_remote_state.sr.outputs.ssh.ca.public_key_openssh
}