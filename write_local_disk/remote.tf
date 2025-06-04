module "write-local-disk" {
  source = "../modules/remote_exec"
  hosts = [
    for _, host in local.hosts :
    cidrhost(local.networks.service.prefix, host.netnum)
  ]
  command = [
    <<-EOF
    set -ex -o pipefail

    export image_url=$(xargs -n1 -a /proc/cmdline | grep ^coreos.live.rootfs_url= | sed -r 's/coreos.live.rootfs_url=(.*)-rootfs(.*)\.img$/\1-iso\2.iso/')
    export ignition_url=$(xargs -n1 -a /proc/cmdline | grep ^ignition.config.url= | sed 's/ignition.config.url=//')
    export disk=/dev/$(lsblk -ndo pkname /dev/disk/by-label/fedora-coreos-* | head -1)

    curl $image_url --output coreos.iso
    curl $ignition_url | coreos-installer iso ignition embed coreos.iso

    sudo dd if=coreos.iso of=$disk bs=4M
    sync
    rm coreos.iso
    EOF
  ]
}