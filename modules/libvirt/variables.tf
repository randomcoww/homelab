variable "ca" {
  type = map(string)
}

variable "certs" {
  type = any
}

variable "dns_names" {
  type = list(string)
}

variable "ip_addresses" {
  type = list(string)
}