variable "cluster_service_endpoint" {
  type = string
}

variable "release" {
  type = string
}

variable "affinity" {
  type    = any
  default = {}
}

variable "replicas" {
  type    = number
  default = 1
}

variable "images" {
  type = object({
    matchbox   = string
    mountpoint = string
  })
}

variable "ports" {
  type = object({
    matchbox     = number
    matchbox_api = number
  })
}

variable "service_ip" {
  type = string
}

variable "ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "s3_mount_access_key_id" {
  type = string
}

variable "s3_mount_secret_access_key" {
  type = string
}

variable "s3_mount_endpoint" {
  type = string
}

variable "s3_mount_bucket" {
  type = string
}

variable "s3_mount_extra_args" {
  type    = list(string)
  default = []
}