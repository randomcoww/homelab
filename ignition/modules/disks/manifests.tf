resource "random_password" "luks-key" {
  for_each = local.partitions

  length  = 512
  special = false
}

locals {
  disks = {
    for name, disk in var.disks :
    name => merge(disk, {
      partitions = [
        for i, partition in disk.partitions :
        merge(partition, {
          number          = i + 1
          label           = "${name}${i + 1}"
          part            = "/dev/disk/by-partlabel/${name}${i + 1}"
          device          = "/dev/disk/by-id/dm-name-${name}${i + 1}"
          mount_unit_name = join("-", compact(split("/", replace(partition.mount_path, "-", "\\x2d"))))
          mount_options   = lookup(partition, "mount_options", ["noatime", "nodiratime", "discard"])
          format          = lookup(partition, "format", "xfs")
          wipe            = lookup(partition, "wipe", false)
          mount_timeout   = lookup(partition, "mount_timeout", 10)
          start_mib       = lookup(partition, "start_mib", 0)
          size_mib        = lookup(partition, "size_mib", 0)
          bind_mounts = [
            for j, bind_mount in lookup(partition, "bind_mounts", []) :
            merge(bind_mount, {
              mount_unit_name = join("-", compact(split("/", replace(bind_mount.mount_path, "-", "\\x2d"))))
            })
          ]
        })
      ]
      wipe = lookup(disk, "wipe", alltrue([
        for partition in disk.partitions :
        lookup(partition, "wipe", false)
      ]))
    })
  }

  partitions = {
    for partition in flatten([
      for _, disk in local.disks :
      disk.partitions
    ]) :
    partition.label => partition
  }

  ignition_snippets = concat([
    for f in fileset(".", "${path.module}/templates/*.yaml") :
    templatefile(f, {
      ignition_version = var.ignition_version
      disks            = local.disks
    })
    ], [
    yamlencode({
      variant = "fcos"
      version = var.ignition_version
      storage = {
        disks = [
          for _, disk in local.disks :
          {
            device     = disk.device
            wipe_table = disk.wipe
            partitions = [
              for partition in disk.partitions :
              {
                label                = partition.label
                number               = partition.number
                start_mib            = partition.start_mib
                size_mib             = partition.size_mib
                wipe_partition_entry = partition.wipe
              }
            ]
          }
        ]
        luks = [
          for label, partition in local.partitions :
          {
            label       = label
            name        = label
            device      = partition.part
            wipe_volume = partition.wipe
            discard     = true
            open_options = [
              "--perf-no_read_workqueue",
              "--perf-no_write_workqueue",
            ]
            key_file = {
              inline = random_password.luks-key[label].result
            }
          }
        ]
        filesystems = [
          for label, partition in local.partitions :
          {
            label           = label
            path            = partition.mount_path
            device          = partition.device
            format          = partition.format
            wipe_filesystem = partition.wipe
            options = [
              for option in lookup(partition, "options", []) :
              option
            ]
          }
        ]
      }
    })
  ])
}