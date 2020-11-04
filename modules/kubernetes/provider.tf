provider "kubernetes-alpha" {
  host                   = var.cluster_endpoint.apiserver_endpoint
  cluster_ca_certificate = var.cluster_endpoint.kubernetes_ca_pem
  client_certificate     = var.cluster_endpoint.kubernetes_cert_pem
  client_key             = var.cluster_endpoint.kubernetes_private_key_pem
}