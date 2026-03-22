variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "scrape_configs" {
  type    = any
  default = []
}

variable "server_files" {
  type    = any
  default = {}
}

variable "ingress_hostname" {
  type = string
}

variable "gateway_ref" {
  type = any
}
