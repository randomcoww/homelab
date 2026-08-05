output "ignition_snippet" {
  value = yamlencode({
    variant = "fcos"
    version = var.butane_version
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
        for _, partition in local.partitions :
        {
          label       = partition.label
          name        = partition.label
          device      = partition.part
          wipe_volume = partition.wipe
          discard     = true
          open_options = [
            "--perf-no_read_workqueue",
            "--perf-no_write_workqueue",
          ]
          key_file = {
            inline = random_password.luks-key[partition.label].result
          }
        }
      ]
      filesystems = [
        for _, partition in local.partitions :
        {
          # No need to mount this during ignition. Also skips long relabling step
          # path            = partition.mount_path
          label           = partition.label
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
    systemd = {
      units = flatten([
        for _, disk in local.disks : [
          for _, partition in disk.partitions :
          {
            name     = "${partition.mount_unit_name}.mount"
            enabled  = true
            contents = <<-EOF
              [Unit]
              ConditionPathExists=${partition.device}

              [Mount]
              What=${partition.device}
              Where=${partition.mount_path}
              Type=${partition.format}
              Options=${join(",", partition.mount_options)}

              [Install]
              WantedBy=local-fs.target
              EOF
          }
        ]
      ])
    }
  })
}