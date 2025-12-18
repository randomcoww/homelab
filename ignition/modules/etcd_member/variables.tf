variable "butane_version" {
  type = string
}

variable "fw_mark" {
  type = string
}

variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "host_key" {
  type = string
}

variable "cluster_token" {
  type = string
}

variable "ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "peer_ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "images" {
  type = object({
    etcd_wrapper = string
    etcd         = string
  })
}

variable "ports" {
  type = object({
    etcd_client  = number
    etcd_peer    = number
    etcd_metrics = number
  })
}

variable "node_ip" {
  type = string
}

variable "members" {
  type = map(string)
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

variable "static_pod_path" {
  type = string
}

variable "config_base_path" {
  type    = string
  default = "/var/lib"
}

variable "data_storage_path" {
  type = string
}