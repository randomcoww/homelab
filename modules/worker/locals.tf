locals {
  controller_config_path = "/var/lib/kubelet/config"

  certs = {
    worker = {
      for cert_name, cert in var.common_certs.worker :
      cert_name => merge(cert, {
        path = "${local.controller_config_path}/worker-${cert_name}.pem"
      })
    }
  }

  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      worker_certs                  = local.certs.worker
      container_images              = var.container_images
      cluster_name                  = var.kubernetes_cluster_name
      kubernetes_pod_network_prefix = var.kubernetes_pod_network_prefix
      apiserver_ip                  = var.apiserver_ip
      apiserver_port                = var.apiserver_port
      kubelet_config_path           = local.controller_config_path
      kubelet_node_labels           = var.kubelet_node_labels
      static_pod_manifest_path      = "/var/lib/kubelet/manifests"
      kubernetes_cluster_domain     = var.kubernetes_cluster_domain
      kubernetes_cluster_dns_netnum = var.kubernetes_cluster_dns_netnum
    })
  ]
}