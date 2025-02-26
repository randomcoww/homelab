module "write-sentinel-file" {
  source = "../modules/remote_exec"
  hosts = [
    for _, host in local.hosts :
    cidrhost(local.networks.service.prefix, host.netnum) if lookup(host, "enable_rolling_reboot", false)
  ]
  command = [
    "sudo touch /var/run/reboot-required",
  ]
}