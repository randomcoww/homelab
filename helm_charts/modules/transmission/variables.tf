variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "release" {
  type = string
}

variable "images" {
  type = object({
    transmission = string
    wireguard    = string
  })
}

variable "ports" {
  type = object({
    transmission = number
  })
}

variable "wireguard_config" {
  type = string
}

variable "torrent_done_script" {
  type = string
}

variable "transmission_settings" {
  type = map(string)
}

variable "service_hostname" {
  type = string
}

variable "ingress_class_name" {
  type = string
}

variable "ingress_cert_issuer" {
  type = string
}

variable "ingress_auth_url" {
  type = string
}

variable "ingress_auth_signin" {
  type = string
}

variable "volume_claim_size" {
  type = string
}

variable "storage_class" {
  type = string
}