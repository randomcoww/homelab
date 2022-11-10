variable "ssh_ca_public_key_openssh" {
  type = string
}

variable "wlan_interface" {
  type = string
}

variable "sunshine" {
  type = object({
    username = string
    password = string
  })
}