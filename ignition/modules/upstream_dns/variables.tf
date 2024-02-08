variable "ignition_version" {
  type = string
}

variable "upstream_dns" {
  type = object({
    ip       = string
    hostname = string
  })
}