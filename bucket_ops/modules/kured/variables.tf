variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "release" {
  type    = string
  default = "0.1.0"
}

variable "images" {
  type = object({
    kured = object({
      repository = string
      tag        = string
    })
  })
}

variable "kured_config" {
  type    = any
  default = {}
}