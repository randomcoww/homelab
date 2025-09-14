locals {
  bind_mount_path = "/var/devfiles"
  temp_image_path = "/var/tmp/coreos-temp.iso"
}

module "write-local-disk" {
  for_each = local.hosts

  source = "../modules/remote_exec"
  host   = cidrhost(local.networks.service.prefix, each.value.netnum)
  command = [
    <<-EOF
    set -ex -o pipefail

    cleanup() {
      if mountpoint -q ${local.bind_mount_path}; then
        sync
        sudo umount ${local.bind_mount_path}
      fi
      sudo rmdir ${local.bind_mount_path}

      if [ -f ${local.temp_image_path} ]; then
        sync
        rm ${local.temp_image_path}
      fi
    }
    trap cleanup EXIT

    sudo mkdir -p ${local.bind_mount_path}
    image_url=$(xargs -n1 -a /proc/cmdline | grep ^coreos.live.rootfs_url= | sed -r 's/coreos.live.rootfs_url=(.*)-rootfs(.*)\.img$/\1-iso\2.iso/')
    if [ -z "$image_url" ]; then
      exit 1
    fi
    disk=$(lsblk -ndo pkname /dev/disk/by-label/fedora-coreos-* | head -1)
    if [ -z "$disk" ]; then
      exit 1
    fi

    # Compare image version
    backup_label=$(sudo blkid /dev/$disk -s LABEL -o value)
    current_label=$(cat /proc/cmdline | awk '{print $1}' | sed -r 's/-live-kernel.*//')
    if [ "$backup_label" != "$current_label" ]; then
      curl $image_url --output ${local.temp_image_path}
      sudo cat /run/ignition.json | coreos-installer iso ignition embed ${local.temp_image_path}

      sudo dd if=${local.temp_image_path} of=/dev/$disk bs=4M
      exit 0
    fi

    # Compare ignition
    sudo bindfs --block-devices-as-files /dev ${local.bind_mount_path}
    backup_ign=$(sudo coreos-installer iso ignition show ${local.bind_mount_path}/$disk | sha256sum | awk '{print $1}')
    current_ign=$(sudo cat /run/ignition.json | sha256sum | awk '{print $1}')
    if [ "$backup_ign" != "$current_ign" ]; then
      sudo cat /run/ignition.json | sudo coreos-installer iso ignition embed ${local.bind_mount_path}/$disk -f
    fi
    EOF
  ]
  triggers_replace = data.terraform_remote_state.matchbox-client.outputs.config[each.key]
}