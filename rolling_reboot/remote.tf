module "write-sentinel-file" {
  for_each = local.hosts

  source = "../modules/remote_exec"
  host   = cidrhost(local.networks.service.prefix, each.value.netnum)
  command = [
    "sudo touch /var/run/reboot-required",
  ]
  triggers_replace = data.terraform_remote_state.matchbox-client.outputs.config[each.key]
}