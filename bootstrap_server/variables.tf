variable "host_ip" {
  type = string
}

variable "ipxe_boot_path" {
  type    = string
  default = "/ipxe.efi"
}

variable "assets_path" {
  type = string
}