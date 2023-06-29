variable "ssh_ca_public_key_openssh" {
  type = string
}

variable "wlan_interface" {
  type = string
}

variable "wireguard_client" {
  type = object({
    Interface = map(string)
    Peer      = map(string)
  })
}