locals {
  pki_path = "/var/lib/kubelet/pki"

  pki = {
    for cert_name, cert in {
      ca_cert = {
        content = var.ca.cert_pem
      }
      bootstrap_cert = {
        content = tls_locally_signed_cert.bootstrap.cert_pem
      }
      bootstrap_key = {
        content = tls_private_key.bootstrap.private_key_pem
      }
    } :
    cert_name => merge(cert, {
      path = "${local.pki_path}/${cert_name}.pem"
    })
  }

  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      cluster_name              = var.cluster_name
      pki_path                  = local.pki_path
      pki                       = local.pki
      node_labels               = var.node_labels
      node_taints               = var.node_taints
      apiserver_endpoint        = var.apiserver_endpoint
      cluster_dns_ip            = var.cluster_dns_ip
      cluster_domain            = var.cluster_domain
      kubelet_port              = var.kubelet_port
      cni_bridge_interface_name = var.cni_bridge_interface_name

      static_pod_manifest_path = var.static_pod_manifest_path
      container_storage_path   = var.container_storage_path
      kubelet_root_path        = "/var/lib/kubelet"
      config_path              = "/var/lib/kubelet/config"
    })
  ]
}