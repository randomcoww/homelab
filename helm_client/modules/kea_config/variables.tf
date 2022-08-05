variable "resource_name" {
  type = string
}

variable "service_ips" {
  type = list(string)
}

variable "ipxe_file_url" {
  type = string
}

variable "tftp_server" {
  type = string
}

variable "cluster_domain" {
  type = string
}

variable "networks" {
  type = list(object({
    prefix              = string
    mtu                 = number
    routers             = list(string)
    domain_name_servers = list(string)
    pools               = list(string)
  }))
}

variable "shared_data_path" {
  type    = string
  default = "/var/lib/kea"
}

variable "kea_hooks_libraries_path" {
  type    = string
  default = "/usr/local/lib/kea/hooks"
}

variable "kea_peer_port" {
  type    = number
  default = 22000
}