variable "ignition_version" {
  type = string
}

variable "private_key" {
  type = string
}

variable "public_key" {
  type = string
}

variable "endpoint" {
  type = string
}

variable "address" {
  type = string
}

variable "dns" {
  type    = string
  default = ""
}

variable "allowed_ips" {
  type    = string
  default = "0.0.0.0/0,::0/0"
}

variable "uid" {
  type = number
}