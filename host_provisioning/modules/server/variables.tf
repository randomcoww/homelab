variable "butane_version" {
  type = string
}

variable "fw_mark" {
  type = string
}

variable "key_id" {
  type = string
}

variable "ssh_ca" {
  type = object({
    algorithm          = string
    private_key_pem    = string
    public_key_openssh = string
  })
}

variable "users" {
  type    = list(any)
  default = []
}

variable "valid_principals" {
  type    = list(string)
  default = []
}

variable "early_renewal_hours" {
  type    = number
  default = 8040
}

variable "validity_period_hours" {
  type    = number
  default = 8760
}

variable "keepalived_path" {
  type = string
}

variable "bird_path" {
  type = string
}

variable "haproxy_path" {
  type = string
}

variable "bird_cache_table" {
  type = object({
    name     = string
    table_id = number
  })
}

variable "bgp_router_id" {
  type = string
}

variable "bgp_port" {
  type = number
}

variable "bgp_neighbor_netnums" {
  type = map(number)
}

variable "bgp_prefix" {
  type = string
}

variable "bgp_as" {
  type = number
}

variable "backup_bind_mount_path" {
  type    = string
  default = "/var/devfiles"
}

variable "backup_temp_image_path" {
  type    = string
  default = "/var/tmp/coreos-temp.iso"
}