variable "butane_version" {
  type = string
}

variable "upstream_dns" {
  type = list(object({
    ip       = string
    hostname = string
  }))
}