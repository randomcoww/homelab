locals {
  reboot_required_host_file = "/usr/local/bin/reboot-required.sh"
}

module "configmap" {
  source    = "../../../modules/configmap"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    basename(local.reboot_required_host_file) = <<-EOF
    #!/bin/bash
    set -xe -o pipefail

    if [ -f /var/run/reboot-required ]; then
      exit 0
    fi
    if [ -z $(xargs -n1 -a /proc/cmdline | grep ^coreos.live.rootfs_url=) ]; then
      exit 0
    fi
    ipxe_url=$(xargs -n1 -a /proc/cmdline | grep ^ipxe.url= | sed -r 's/^ipxe.url=//')
    remote_digest=$(curl -fsSL --remove-on-error $ipxe_url | grep ^kernel | xargs -n1 | grep ^digest= | sed -e 's/^digest=//')
    digest=$(xargs -n1 -a /proc/cmdline | grep ^digest= | sed -e 's/^digest=//')
    if [ "$remote_digest" != "$digest" ]; then
      exit 0
    fi
    exit 1
    EOF
  }
}
