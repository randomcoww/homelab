module "write-sentinel-file" {
  for_each = {
    for key, host in local.hosts :
    key => host
    if lookup(host, "enable_rolling_reboot", false)
  }

  source = "../modules/remote_exec"
  host   = cidrhost(local.networks.service.prefix, each.value.netnum)
  command = [
    <<-EOF
    set -ex -o pipefail

    if [ -z $(xargs -n1 -a /proc/cmdline | grep ^coreos.live.rootfs_url=) ]; then
      sudo touch /var/run/reboot-required
    else
      echo "ok"
    fi
    EOF
  ]
  triggers_replace = [
    timestamp(),
  ]
}