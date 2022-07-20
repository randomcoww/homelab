
variable "cluster_token" {
  type = string
}

variable "cluster_hosts" {
  type = map(object({
    hostname    = string
    client_ip   = string
    peer_ip     = string
    client_port = number
    peer_port   = number
  }))
}

variable "aws_region" {
  type = string
}

variable "s3_backup_bucket" {
  type = string
}