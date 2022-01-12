locals {
  disks = {
    for name, disk in var.disks :
    name => merge(disk, {
      partitions = [
        for i, partition in disk.partitions :
        merge(partition, {
          number            = i + 1
          label             = "${name}${i + 1}"
          device            = join("/", ["/dev/disk/by-partlabel", "${name}${i + 1}"])
          systemd_unit_name = join("-", compact(split("/", replace(partition.mount_path, "-", "\\x2d"))))
          mount_options     = lookup(partition, "mount_options", ["noatime", "nodiratime", "discard"])
          format            = lookup(partition, "format", "xfs")
          wipe              = lookup(partition, "wipe", false)
          mount_timeout     = lookup(partition, "mount_timeout", 10)
          start_mib         = lookup(partition, "start_mib", 0)
          size_mib          = lookup(partition, "size_mib", 0)
        })
      ]
      wipe = lookup(disk, "wipe", alltrue([
        for partition in disk.partitions :
        lookup(partition, "wipe", false)
      ]))
    })
  }

  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      disks = local.disks
    })
  ]
}