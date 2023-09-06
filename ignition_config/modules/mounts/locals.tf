locals {
  mounts = [
    for i, mount in var.mounts :
    merge(mount, {
      mount_unit_name  = join("-", compact(split("/", replace(mount.mount_path, "-", "\\x2d"))))
      device_unit_name = join("-", compact(split("/", replace(mount.device, "-", "\\x2d"))))
      mount_options    = lookup(mount, "mount_options", ["noatime", "nodiratime", "discard"])
      format           = lookup(mount, "format", "xfs")
      mount_timeout    = lookup(mount, "mount_timeout", 10)
      bind_mounts = [
        for j, bind_mount in lookup(mount, "bind_mounts", []) :
        merge(bind_mount, {
          mount_unit_name = join("-", compact(split("/", replace(bind_mount.mount_path, "-", "\\x2d"))))
        })
      ]
    })
  ]

  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      mounts = local.mounts
    })
  ]
}