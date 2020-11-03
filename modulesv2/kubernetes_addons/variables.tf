variable "cluster_endpoint" {
  type = map(string)
}

variable "kubernetes_manifests" {
  type = list(string)
}