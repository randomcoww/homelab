locals {
  addon_manifests = {
    for f in fileset(".", "${path.module}/manifests/*.yaml") :
    basename(f) => templatefile(f, {
      container_images                      = var.container_images
      flannel_host_gateway_interface_name   = var.flannel_host_gateway_interface_name
      kubernetes_pod_network_prefix         = var.kubernetes_pod_network_prefix
      kubernetes_service_network_prefix     = var.kubernetes_service_network_prefix
      kubernetes_service_network_dns_netnum = var.kubernetes_service_network_dns_netnum
      kubernetes_cluster_domain             = var.kubernetes_cluster_domain
      internal_domain                       = var.internal_domain
      internal_dns_ip                       = var.internal_dns_ip
      kubernetes_external_dns_ip            = var.kubernetes_external_dns_ip
      metallb_network_prefix                = var.metallb_network_prefix
      metallb_subnet                        = var.metallb_subnet
      apiserver_ip                          = var.apiserver_ip
      apiserver_port                        = var.apiserver_port
      kubernetes_minio_ip                   = var.kubernetes_minio_ip
      minio_port                            = var.minio_port
      minio_console_port                    = var.minio_console_port
    })
  }
}