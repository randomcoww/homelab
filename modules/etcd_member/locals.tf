locals {
  certs_path = "/var/lib/etcd/pki"

  certs = {
    for cert_name, cert in merge(var.certs, {
      cert = {
        content = tls_locally_signed_cert.etcd.cert_pem
      }
      key = {
        content = tls_private_key.etcd.private_key_pem
      }
      peer_cert = {
        content = tls_locally_signed_cert.etcd-peer.cert_pem
      }
      peer_key = {
        content = tls_private_key.etcd-peer.private_key_pem
      }
      client_cert = {
        content = tls_locally_signed_cert.etcd-client.cert_pem
      }
      client_key = {
        content = tls_private_key.etcd-client.private_key_pem
      }
    }) :
    cert_name => merge(cert, {
      path = "${local.certs_path}/${cert_name}.pem"
    })
  }

  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, merge(var.template_params, {
      static_pod_manifest_path     = var.static_pod_manifest_path
      certs_path                   = local.certs_path
      backup_path                  = "/var/lib/etcd/backup"
      etcd_manifest_file           = "etcd.json"
      etcd_backup_file             = "etcd.db"
      certs                        = local.certs
      etcd_container_image         = var.etcd_container_image
      etcd_wrapper_container_image = var.etcd_wrapper_container_image
    }))
  ]
}