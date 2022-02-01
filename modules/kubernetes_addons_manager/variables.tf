variable "container_images" {
  type = map(string)
}

variable "kubernetes_common_certs" {
  type = any
}

variable "apiserver_ip" {
  type = string
}

variable "apiserver_port" {
  type = number
}


variable "kubernetes_cluster_name" {
  type = string
}

variable "kubernetes_ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "static_pod_manifest_path" {
  type = string
}

variable "addon_manifests" {
  type = map(string)
}