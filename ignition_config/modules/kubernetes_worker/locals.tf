locals {
  certs_path = "/var/lib/kubelet/pki"

  certs = {
    for cert_name, cert in merge(var.certs, {
      bootstrap_cert = {
        content = tls_locally_signed_cert.bootstrap.cert_pem
      }
      bootstrap_key = {
        content = tls_private_key.bootstrap.private_key_pem
      }
    }) :
    cert_name => merge(cert, {
      path = "${local.certs_path}/${cert_name}.pem"
    })
  }

  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      cluster_name              = var.cluster_name
      container_storage_path    = var.container_storage_path
      kubelet_root_path         = "/var/lib/kubelet"
      certs_path                = local.certs_path
      config_path               = "/var/lib/kubelet/config"
      certs                     = local.certs
      node_labels               = var.node_labels
      node_taints               = var.node_taints
      apiserver_endpoint        = var.apiserver_endpoint
      cluster_dns_ip            = var.cluster_dns_ip
      cni_bridge_interface_name = var.cni_bridge_interface_name
      cluster_domain            = var.cluster_domain
      static_pod_manifest_path  = var.static_pod_manifest_path
      kubelet_port              = var.kubelet_port
    })
  ]
}