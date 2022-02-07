variable "hostname" {
  type = string
}

variable "interfaces" {
  type = map(map(string))
}

variable "container_images" {
  type = map(string)
}

variable "host_netnum" {
  type = number
}

variable "vrrp_netnum" {
  type = number
}

variable "dhcp_server_subnet" {
  type = object({
    newbit = number
    netnum = number
  })
}

variable "kea_peers" {
  type = list(object({
    name   = string
    netnum = number
    role   = string
  }))
}

variable "kea_peer_port" {
  type = number
}

variable "internal_domain_dns_ip" {
  type = string
}

variable "internal_domain" {
  type = string
}

variable "pxeboot_file_name" {
  type = string
}

variable "static_pod_manifest_path" {
  type = string
}