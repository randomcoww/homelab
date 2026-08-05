resource "random_password" "luks-key" {
  for_each = {
    for _, partition in local.partitions :
    partition.label => local.partitions
  }

  length  = 512
  special = false
}

locals {
  disks = [
    for _, disk in var.disks :
    merge(disk, {
      partitions = [
        for i, partition in disk.partitions :
        merge(partition, {
          number          = i + 1
          label           = "${disk.label}${i + 1}"
          part            = "/dev/disk/by-partlabel/${disk.label}${i + 1}"
          device          = "/dev/disk/by-id/dm-name-${disk.label}${i + 1}"
          mount_unit_name = join("-", compact(split("/", replace(partition.mount_path, "-", "\\x2d"))))
          mount_options   = lookup(partition, "mount_options", ["noatime", "nodiratime", "discard"])
          format          = lookup(partition, "format", "xfs")
          wipe            = lookup(partition, "wipe", false)
          mount_timeout   = lookup(partition, "mount_timeout", 10)
          start_mib       = lookup(partition, "start_mib", 0)
          size_mib        = lookup(partition, "size_mib", 0)
        })
      ]
      wipe = lookup(disk, "wipe", alltrue([
        for partition in disk.partitions :
        lookup(partition, "wipe", false)
      ]))
    })
  ]

  partitions = [
    for partition in flatten([
      for _, disk in local.disks :
      disk.partitions
    ]) :
    partition
  ]
}