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
    alpaca_stream = string
  })
}

variable "ports" {
  type = object({
    alpaca_stream = number
  })
}

variable "affinity" {
  type    = any
  default = {}
}

variable "service_hostname" {
  type = string
}

variable "alpaca_api_key_id" {
  type = string
}

variable "alpaca_api_secret_key" {
  type = string
}

variable "alpaca_api_base_url" {
  type = string
}