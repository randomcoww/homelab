locals {
  backup_bind_mount_path = "/var/dev"
  backup_temp_image_path = "/var/tmp/coreos.iso"
}

module "daemonset" {
  source = "../../../modules/daemonset"

  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  affinity  = var.affinity
  template_spec = {
    initContainers = [
      {
        name  = var.name
        image = "${var.images.backup-runner.repository}:${var.images.backup-runner.tag}"
        command = [
          "bash",
          "-c",
          <<-EOF
          set -xe -o pipefail
          mkdir -p ${local.backup_bind_mount_path}

          cleanup() {
            if mountpoint -q ${local.backup_bind_mount_path}; then
              sync
              umount ${local.backup_bind_mount_path}
            fi
            rmdir ${local.backup_bind_mount_path}

            if [ -f ${local.backup_temp_image_path} ]; then
              sync
              rm ${local.backup_temp_image_path}
            fi
          }
          trap cleanup EXIT

          # Only exists in network boot environment. Exit otherwise
          image_url=$(xargs -n1 -a /proc/cmdline | grep ^${var.liveiso_url_karg}= | sed -r 's/^${var.liveiso_url_karg}=//')
          if [ -z "$image_url" ]; then
            exit 0
          fi

          # TODO: This uses the first USB device. Might want to control this better
          disk=$(lsblk -ndo kname /dev/disk/by-id/usb-* | head -1)
          if [ -z "$disk" ]; then
            exit 1
          fi

          # This mounts to /dev to another filesystem. It allows coreos-installer to treat the USB disk as ISO9660 image file
          bindfs --block-devices-as-files /dev ${local.backup_bind_mount_path}

          backup_tag=$(coreos-installer iso kargs show ${local.backup_bind_mount_path}/$disk | xargs -n1 | grep '^${var.cosa_build_tag_karg}' | sed -r 's/^${var.cosa_build_tag_karg}=//')
          current_tag=$(xargs -n1 -a /proc/cmdline | grep '^${var.cosa_build_tag_karg}' | sed -r 's/^${var.cosa_build_tag_karg}=//')
          if [ "$backup_tag" != "$current_tag" ]; then
            curl -fsSL --remove-on-error $image_url --output ${local.backup_temp_image_path}
            cat /run/ignition.json | coreos-installer iso ignition embed ${local.backup_temp_image_path}

            dd if=${local.backup_temp_image_path} of=/dev/$disk bs=4M
            exit 0
          fi

          # Compare ignition
          backup_ign=$(coreos-installer iso ignition show ${local.backup_bind_mount_path}/$disk | sha256sum | awk '{print $1}')
          current_ign=$(cat /run/ignition.json | sha256sum | awk '{print $1}')
          if [ "$backup_ign" != "$current_ign" ]; then
            cat /run/ignition.json | coreos-installer iso ignition embed ${local.backup_bind_mount_path}/$disk -f
          fi
          EOF
        ]
        securityContext = {
          privileged = true
        }
        volumeMounts = [
          {
            name      = "dev-disk"
            mountPath = "/dev/disk"
          },
          {
            name      = "ignition"
            mountPath = "/run/ignition.json"
            readOnly  = true
          },
          {
            name      = "ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            readOnly  = true
          },
        ]
        resources = {
          requests = {
            memory = "256Mi"
          }
        }
      },
    ]
    containers = [
      {
        name  = "${var.name}-sleep"
        image = "${var.images.backup-runner.repository}:${var.images.backup-runner.tag}"
        command = [
          "bash",
          "-c",
          "tail -f /dev/null",
        ]
      },
    ]
    volumes = [
      {
        name = "dev-disk"
        hostPath = {
          path = "/dev/disk"
          type = "Directory"
        }
      },
      {
        name = "ignition"
        hostPath = {
          path = "/run/ignition.json"
          type = "File"
        }
      },
      {
        name = "ca-trust-bundle"
        hostPath = {
          path = "/etc/ssl/certs/ca-certificates.crt"
          type = "File"
        }
      },
    ]
  }
}