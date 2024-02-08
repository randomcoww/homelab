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
    bsimp = string
  })
}

variable "ports" {
  type = object({
    bsimp = number
  })
}

variable "affinity" {
  type    = any
  default = {}
}

variable "s3_endpoint" {
  type = string
}

variable "s3_resource" {
  type = string
}

variable "s3_access_key_id" {
  type = string
}

variable "s3_secret_access_key" {
  type = string
}

variable "service_hostname" {
  type = string
}

variable "ingress_class_name" {
  type = string
}

variable "nginx_ingress_annotations" {
  type = map(string)
}