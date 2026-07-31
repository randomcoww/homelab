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
    mountpoint_s3_csi = object({
      repository = string
      tag        = string
    })
  })
}

variable "kubelet_root_path" {
  type = string
}

variable "minio_user" {
  type = object({
    id     = string
    secret = string
  })
}