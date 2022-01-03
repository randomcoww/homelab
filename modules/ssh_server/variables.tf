variable "user" {
  type = any
}

variable "hostname" {
  type = string
}

variable "interfaces" {
  # {
  #   en0 = {
  #     mac = "8c-8c-aa-e3-58-62"
  #     mtu = 9000
  #     taps = {
  #       lan = {
  #         netnum = 1
  #         mdns = true
  #         dhcp = true
  #       }
  #     }
  #   }
  # }
  type    = any
  default = {}
}

variable "vlans" {
  # {
  #   lan = {
  #     network = "192.168.126.0/24"
  #     vlan_id = 1
  #   }
  # }
  type    = any
  default = {}
}

variable "ca" {
  type = object({
    ssh = object({
      algorithm          = string
      private_key_pem    = string
      public_key_openssh = string
    })
  })
}