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
    mpd    = string
    mympd  = string
    rclone = string
  })
}

variable "ports" {
  type = object({
    mympd             = number
    rclone            = number
    audio_output_base = number
  })
}

variable "audio_outputs" {
  type    = list(any)
  default = []
}

variable "affinity" {
  type    = any
  default = {}
}

variable "extra_configs" {
  type    = map(any)
  default = {}
}

variable "s3_resource" {
  type = string
}

variable "s3_endpoint" {
  type = string
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

variable "storage_access_modes" {
  type = list(string)
  default = [
    "ReadWriteOnce",
  ]
}