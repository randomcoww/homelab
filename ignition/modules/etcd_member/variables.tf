variable "ignition_version" {
  type = string
}

variable "fw_mark" {
  type = string
}

variable "name" {
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

variable "members" {
  type = map(string)
}

variable "etcd_ips" {
  type = list(string)
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

variable "healthcheck_interval" {
  type    = string
  default = "2s"
}

variable "backup_interval" {
  type    = string
  default = "15m"
}

variable "healthcheck_fail_count_allowed" {
  type    = number
  default = 16
}

variable "readiness_fail_count_allowed" {
  type    = number
  default = 32
}

variable "auto_compaction_retention" {
  type    = number
  default = 1
}

variable "static_pod_path" {
  type = string
}

variable "config_base_path" {
  type    = string
  default = "/var/lib"
}