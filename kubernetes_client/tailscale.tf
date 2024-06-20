module "tailscale" {
  source  = "./modules/tailscale"
  name    = "tailscale"
  release = "0.1.1"
  images = {
    tailscale = local.container_images.tailscale
  }

  tailscale_auth_key = data.terraform_remote_state.sr.outputs.tailscale_auth_key
  tailscale_extra_envs = [
    {
      name  = "TS_ACCEPT_DNS"
      value = false
    },
    {
      name  = "TS_DEBUG_FIREWALL_MODE"
      value = "nftables"
    },
    {
      name = "TS_EXTRA_ARGS"
      value = join(",", [
        "--advertise-exit-node",
      ])
    },
    {
      name = "TS_ROUTES"
      value = join(",", [
        local.networks.lan.prefix,
        local.networks.service.prefix,
        local.networks.kubernetes.prefix,
      ])
    },
  ]
  aws_region             = data.terraform_remote_state.sr.outputs.ssm.tailscale.aws_region
  ssm_access_key_id      = data.terraform_remote_state.sr.outputs.ssm.tailscale.access_key_id
  ssm_secret_access_key  = data.terraform_remote_state.sr.outputs.ssm.tailscale.secret_access_key
  ssm_tailscale_resource = data.terraform_remote_state.sr.outputs.ssm.tailscale.resource
}