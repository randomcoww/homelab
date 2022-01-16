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

      # backup #
      aws_access_key_id     = var.aws_access_key_id
      aws_secret_access_key = var.aws_secret_access_key
      aws_region            = var.aws_region
      etcd_s3_backup_path   = var.etcd_s3_backup_path
    })
  ]
}