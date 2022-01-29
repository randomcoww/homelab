locals {
  certs_path = "/var/lib/kubelet/pki"

  certs = {
    worker = {
      for cert_name, cert in var.common_certs.worker :
      cert_name => merge(cert, {
        path = "${local.certs_path}/worker-${cert_name}.pem"
      })
    }
  }

  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      worker_certs                          = local.certs.worker
      container_images                      = var.container_images
      cluster_name                          = var.kubernetes_cluster_name
      kubernetes_service_network_prefix     = var.kubernetes_service_network_prefix
      kubernetes_service_network_dns_netnum = var.kubernetes_service_network_dns_netnum
      apiserver_ip                          = var.apiserver_ip
      apiserver_port                        = var.apiserver_port
      kubelet_node_labels                   = var.kubelet_node_labels
      static_pod_manifest_path              = var.static_pod_manifest_path
      kubelet_root_path                     = "/var/lib/kubelet/root"
      certs_path                            = local.certs_path
      config_path                           = "/var/lib/kubelet/config"
      kubelet_port                          = var.kubelet_port
      kubernetes_cluster_domain             = var.kubernetes_cluster_domain
      container_storage_path                = var.container_storage_path
    })
  ]
}