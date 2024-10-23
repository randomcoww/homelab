variable "ignition_version" {
  type = string
}

variable "fw_mark" {
  type = string
}

variable "key_id" {
  type = string
}

variable "ca" {
  type = object({
    algorithm          = string
    private_key_pem    = string
    public_key_openssh = string
  })
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

variable "haproxy_path" {
  type = string
}

variable "keepalived_path" {
  type = string
}

variable "bird_path" {
  type = string
}

variable "bird_cache_table_name" {
  type = string
}

variable "bgp_router_id" {
  type = string
}

variable "bgp_node_prefix" {
  type = string
}

variable "bgp_node_as" {
  type = number
}

variable "bgp_service_prefix" {
  type = string
}

variable "bgp_service_as" {
  type = number
}

variable "bgp_neighbor_netnums" {
  type = map(number)
}

variable "bgp_port" {
  type = number
}