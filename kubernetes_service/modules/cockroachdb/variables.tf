variable "cluster_service_endpoint" {
  type = string
}

variable "headless_suffix" {
  type    = string
  default = "peer"
}

variable "release" {
  type = string
}

variable "replicas" {
  type = number
}

variable "affinity" {
  type    = any
  default = {}
}

variable "images" {
  type = object({
    cockroachdb = string
  })
}

variable "ports" {
  type = object({
    cockroachdb = number
  })
}

variable "ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "extra_configs" {
  type    = map(string)
  default = {}
}

variable "resources" {
  type    = map(any)
  default = {}
}

variable "volume_claim_templates" {
  type    = any
  default = []
}

variable "extra_volumes" {
  type    = any
  default = []
}

variable "extra_volume_mounts" {
  type    = any
  default = []
}