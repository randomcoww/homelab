variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "images" {
  type = object({
    backup-runner = object({
      repository = string
      tag        = string
    })
  })
}

variable "release" {
  type    = string
  default = "0.1.0"
}

variable "affinity" {
  type    = any
  default = {}
}

variable "cosa_build_tag_karg" {
  type = string
}

variable "liveiso_url_karg" {
  type = string
}