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

variable "cluster_members" {
  type = map(string)
}

variable "listen_ips" {
  type = list(string)
}

variable "client_port" {
  type = number
}

variable "peer_port" {
  type = number
}

variable "s3_backup_resource" {
  type = object({
    access_key_id     = string
    secret_access_key = string
    resource          = string
    aws_region        = string
  })
}

variable "static_pod_manifest_path" {
  type = string
}

variable "container_images" {
  type = map(string)
}