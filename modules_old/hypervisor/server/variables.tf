variable "dns_names" {
  type = list(string)
}

variable "ip_addresses" {
  type = list(string)
}

variable "libvirt_ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}