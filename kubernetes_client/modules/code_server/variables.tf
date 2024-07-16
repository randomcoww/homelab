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
    code_server = string
    jfs         = string
  })
}

variable "user" {
  type = string
}

variable "uid" {
  type = number
}

variable "code_server_extra_configs" {
  type = list(object({
    path    = string
    content = string
  }))
  default = []
}

variable "code_server_extra_envs" {
  type = list(object({
    name  = string
    value = any
  }))
  default = []
}

variable "code_server_resources" {
  type    = any
  default = {}
}

variable "code_server_security_context" {
  type    = any
  default = {}
}

variable "affinity" {
  type    = any
  default = {}
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

variable "jfs_minio_endpoint" {
  type = string
}

variable "jfs_minio_resource" {
  type = string
}

variable "jfs_minio_access_key_id" {
  type = string
}

variable "jfs_minio_secret_access_key" {
  type = string
}

variable "jfs_metadata_endpoint" {
  type = string
}

variable "jfs_metadata_ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}