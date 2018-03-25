variable "common_name" {
  default     = ""
}

variable "ca_key_algorithm" {
  default     = ""
}

variable "ca_private_key_pem" {
  default     = ""
}

variable "ca_cert_pem" {
  default     = ""
}

variable "ip_addresses" {
  default     = []
  type        = "list"
}

variable "dns_names" {
  default     = []
  type        = "list"
}
