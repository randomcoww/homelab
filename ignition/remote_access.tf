# SSH client

module "client" {
  for_each = local.members.client
  source   = "./modules/client"

  ignition_version   = local.ignition_version
  public_key_openssh = data.terraform_remote_state.sr.outputs.ssh.ca.public_key_openssh
}

# Remote tailscale node

module "remote" {
  for_each = local.members.remote
  source   = "./modules/remote"

  ignition_version     = local.ignition_version
  tailscale_auth_key   = data.terraform_remote_state.sr.outputs.tailscale_auth_key
  tailscale_state_path = "${local.mounts.home_path}/tailscale"
  images = {
    tailscale = local.container_images.tailscale
  }
}