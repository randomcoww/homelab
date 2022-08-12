variable "resource_name" {
  type = string
}

variable "replica_count" {
  type = number
}

variable "bssid_base" {
  type    = number
  default = 20000000000000
}