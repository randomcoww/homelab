variable "user" {
  type = string
  default = "fcos"
}

variable "networks" {
  # {
  #   lan = {
  #     network = "192.168.126.0/24"
  #     vlan_id = 1
  #   }
  # }
  type = object
  default = {}
}

variable "hosts" {
  # {
  #   kvm-0 = {
  #     hostname = kvm-0.local
  #     interfaces = {
  #       en0 = {
  #         mac = "8c-8c-aa-e3-58-62"
  #         mtu = 9000
  #         taps = {
  #           lan = {
  #             netnum = 1
  #             mdns = true
  #             dhcp = true
  #           }
  #         }
  #       }
  #     }
  #   }
  # }
  type = object
  default = {}
}

variable "internal_network" {
  type = string
  default = "192.168.224.0/26"
}

variable "matchbox_rpc_port" {
  type = number
  default = 58081
}

variable "disks" {
  type = list(object({
    device = string
    mount_path = string
    label = string
  }))
  default = [
    {
      device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_1TB_S5H9NS0N986704R"
      mount_path = "/var/lib/kubelet/pv"
      label = "kubelet"
    }
  ]
}