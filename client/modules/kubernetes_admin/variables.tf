variable "cluster_name" {
  type = string
}

variable "ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "apiserver_endpoint" {
  type = string
}