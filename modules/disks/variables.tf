variable "disks" {
  # {
  #   pv = {
  #     device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_1TB_S5H9NS0N986704R"
  #     partitions = [
  #       {
  #         start_mib = 0
  #         size_mib = 0
  #         mount_path = "/var/lib/kubelet/pv"
  #         wipe = false
  #         mount_timeout = 10
  #         options = ["noatime", "nodiratime", "discard"]
  #       }
  #     ]
  #   }
  # }
  type    = any
  default = {}
}