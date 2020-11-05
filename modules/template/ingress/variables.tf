variable "domains" {
  type = map(string)
}

variable "secrets" {
  type = any
}

variable "hosts" {
  type = any
}

variable "ca_path" {
  type    = string
  default = "/etc/pki/ca-trust/source/anchors/ingress.pem"
}