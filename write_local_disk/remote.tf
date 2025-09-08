module "write-local-disk" {
  for_each = local.hosts

  source = "../modules/remote_exec"
  host   = cidrhost(local.networks.service.prefix, each.value.netnum)
  command = [
    <<-EOF
    set -ex -o pipefail

    export image_url=$(xargs -n1 -a /proc/cmdline | grep ^coreos.live.rootfs_url= | sed -r 's/coreos.live.rootfs_url=(.*)-rootfs(.*)\.img$/\1-iso\2.iso/')
    export disk=/dev/$(lsblk -ndo pkname /dev/disk/by-label/fedora-coreos-* | head -1)

    curl $image_url --output coreos.iso
    sudo cat /run/ignition.json | coreos-installer iso ignition embed coreos.iso

    sudo dd if=coreos.iso of=$disk bs=4M
    sync
    rm coreos.iso
    EOF
  ]
  triggers_replace = [
    timestamp(),
  ]
}