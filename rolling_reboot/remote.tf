module "write-sentinel-file" {
  for_each = local.hosts

  source = "../modules/remote-exec"
  host   = cidrhost(local.networks.service.prefix, each.value.netnum)
  command = [
    "sudo touch /var/run/reboot-required",
  ]
  triggers_replace = {
    always_run = timestamp()
  }
}