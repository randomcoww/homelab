variable "interfaces" {
  type = map(map(string))
}

variable "host_netnum" {
  type = number
}

variable "libvirt_ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}