variable "users" {
  type = any
}

variable "hostname" {
  type = string
}

variable "upstream_dns" {
  type = object({
    ip             = string
    tls_servername = string
  })
}