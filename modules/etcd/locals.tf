locals {
  certs_path = "/var/lib/etcd/pki"

  certs = {
    etcd = {
      for cert_name, cert in merge(var.common_certs.etcd, {
        server_cert = {
          content = tls_locally_signed_cert.etcd-server.cert_pem
        }
        server_key = {
          content = tls_private_key.etcd-server.private_key_pem
        }
      }) :
      cert_name => merge(cert, {
        path = "${local.certs_path}/etcd-${cert_name}.pem"
      })
    }
  }

  etcd_cluster_endpoints = [
    for etcd_host in var.etcd_hosts :
    "https://${cidrhost(var.network_prefix, etcd_host.netnum)}:${var.etcd_client_port}"
  ]

  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      hostname         = var.hostname
      container_images = var.container_images
      etcd_certs       = local.certs.etcd
      network_prefix   = var.network_prefix
      host_netnum      = var.host_netnum
      certs_path       = local.certs_path

      static_pod_manifest_path = var.static_pod_manifest_path
      backup_path              = "/var/lib/etcd/backup"
      etcd_pod_manifest_name   = "etcd.json"
      etcd_hosts               = var.etcd_hosts
      etcd_cluster_token       = var.etcd_cluster_token
      etcd_client_port         = var.etcd_client_port
      etcd_peer_port           = var.etcd_peer_port
      etcd_cluster_endpoints   = local.etcd_cluster_endpoints

      # backup #
      aws_access_key_id     = var.aws_access_key_id
      aws_access_key_secret = var.aws_access_key_secret
      aws_region            = var.aws_region
      s3_backup_path        = var.s3_backup_path
    })
  ]
}