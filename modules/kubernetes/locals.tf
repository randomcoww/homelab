locals {
  controller_config_path = "/var/lib/kubelet/config"

  certs = {
    kubernetes = {
      for cert_name, cert in merge(var.common_certs.kubernetes, {
        apiserver_cert = {
          content = tls_locally_signed_cert.apiserver.cert_pem
        }
        apiserver_key = {
          content = tls_private_key.apiserver.private_key_pem
        }
      }) :
      cert_name => merge(cert, {
        path = "${local.controller_config_path}/kubernetes-${cert_name}.pem"
      })
    }
    etcd = {
      for cert_name, cert in var.common_certs.etcd :
      cert_name => merge(cert, {
        path = "${local.controller_config_path}/etcd-${cert_name}.pem"
      })
    }
  }

  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      container_images = var.container_images
      kubernetes_certs = local.certs.kubernetes
      etcd_certs       = local.certs.etcd
      network_prefix   = var.network_prefix
      host_netnum      = var.host_netnum
      vip_netnum       = var.vip_netnum

      # controller #
      cluster_name                      = var.kubernetes_cluster_name
      kubernetes_service_network_prefix = var.kubernetes_service_network_prefix
      kubernetes_pod_network_prefix     = var.kubernetes_pod_network_prefix
      etcd_servers                      = var.etcd_servers
      etcd_client_port                  = var.etcd_client_port
      apiserver_ip                      = "127.0.0.1"
      apiserver_port                    = var.apiserver_port
      encryption_config_secret          = var.encryption_config_secret
      controller_config_path            = local.controller_config_path
      static_pod_manifest_path          = "/var/lib/kubelet/manifests"
      static_pod_config_path            = "/var/lib/kubelet/podconfig"
    })
  ]
}