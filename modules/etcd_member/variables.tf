variable "ca" {
  type = map(string)
}

variable "peer_ca" {
  type = map(string)
}

variable "certs" {
  type = map(object({
    content = string
    path    = optional(string)
  }))
}

variable "cluster" {
  type = object({
    cluster_token     = string
    cluster_endpoints = list(string)
    initial_cluster   = list(string)
  })
}

variable "backup" {
  type = object({
    aws_access_key_id     = string
    aws_access_key_secret = string
    s3_backup_path        = string
    aws_region            = string
  })
}

variable "member" {
  type = object({
    hostname                    = string
    client_ip                   = string
    peer_ip                     = string
    client_port                 = string
    peer_port                   = string
    initial_advertise_peer_urls = list(string)
    listen_peer_urls            = list(string)
    advertise_client_urls       = list(string)
    listen_client_urls          = list(string)
  })
}

variable "static_pod_manifest_path" {
  type = string
}

variable "container_images" {
  type = map(string)
}