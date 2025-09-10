module "write-local-disk" {
  for_each = local.hosts

  source = "../modules/remote_exec"
  host   = cidrhost(local.networks.service.prefix, each.value.netnum)
  command = [
    <<-EOF
    set -ex -o pipefail

    image_url=$(xargs -n1 -a /proc/cmdline | grep ^coreos.live.rootfs_url= | sed -r 's/coreos.live.rootfs_url=(.*)-rootfs(.*)\.img$/\1-iso\2.iso/')
    if [ -z "$image_url" ]; then
      exit 1
    fi
    disk=$(lsblk -ndo pkname /dev/disk/by-label/fedora-coreos-* | head -1)
    if [ -z "$disk" ]; then
      exit 1
    fi

    curl $image_url --output coreos.iso
    sudo cat /run/ignition.json | coreos-installer iso ignition embed coreos.iso

    sudo dd if=coreos.iso of=/dev/$disk bs=4M
    sync
    rm coreos.iso
    EOF
  ]
  triggers_replace = data.terraform_remote_state.matchbox-client.outputs.config[each.key]
}