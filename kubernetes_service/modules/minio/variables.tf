variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "release" {
  type    = string
  default = "0.1.0"
}

variable "replicas" {
  type    = number
  default = 4
}

variable "images" {
  type = object({
    nginx = string
    minio = object({
      repository = string
      tag        = string
    })
  })
}

variable "minio_credentials" {
  type = object({
    access_key_id     = string
    secret_access_key = string
  })
}

variable "cluster_domain" {
  type = string
}

variable "ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "ports" {
  type = object({
    minio   = number
    metrics = number
  })
}

variable "service_ip" {
  type = string
}

variable "cluster_service_ip" {
  type = string
}