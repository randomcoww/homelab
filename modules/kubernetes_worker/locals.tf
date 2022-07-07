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

  local_storage_volumes = [
    for i in range(var.local_storage_class_volume_count) :
    {
      path              = "${var.local_storage_class_mount_path}/vol${i}"
      target            = "${var.local_storage_class_path}/vol${i}"
      systemd_unit_name = join("-", compact(split("/", replace("${var.local_storage_class_path}/vol${i}", "-", "\\x2d"))))
    }
  ]

  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      cluster_name              = var.cluster_name
      container_storage_path    = var.container_storage_path
      local_storage_volumes     = local.local_storage_volumes
      kubelet_root_path         = "/var/lib/kubelet/root"
      certs_path                = local.certs_path
      config_path               = "/var/lib/kubelet/config"
      certs                     = local.certs
      node_labels               = var.node_labels
      node_taints               = var.node_taints
      apiserver_endpoint        = var.apiserver_endpoint
      service_network           = var.service_network
      pod_network               = var.pod_network
      cni_bridge_interface_name = var.cni_bridge_interface_name
      cluster_domain            = var.cluster_domain
      static_pod_manifest_path  = var.static_pod_manifest_path
      kubelet_port              = var.kubelet_port
    })
  ]
}