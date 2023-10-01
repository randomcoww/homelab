locals {
  pki_path = "/var/lib/etcd/pki"

  pki = {
    for cert_name, cert in {
      ca_cert = {
        content = var.ca.cert_pem
      }
      peer_ca_cert = {
        content = var.peer_ca.cert_pem
      }
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
    } :
    cert_name => merge(cert, {
      path = "${local.pki_path}/${cert_name}.pem"
    })
  }

  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      container_images = var.container_images
      cluster_token    = var.cluster_token
      pki_path         = local.pki_path
      pki              = local.pki
      initial_advertise_peer_urls = join(",", [
        for _, ip in var.listen_ips :
        "https://${ip}:${var.peer_port}"
      ])
      listen_peer_urls = join(",", [
        for _, ip in concat(["127.0.0.1"], var.listen_ips) :
        "https://${ip}:${var.peer_port}"
      ])
      advertise_client_urls = join(",", [
        for _, ip in var.listen_ips :
        "https://${ip}:${var.client_port}"
      ])
      listen_client_urls = join(",", [
        for _, ip in concat(["127.0.0.1"], var.listen_ips) :
        "https://${ip}:${var.client_port}"
      ])
      initial_cluster = join(",", [
        for hostname, ip in var.cluster_members :
        "${hostname}=https://${ip}:${var.peer_port}"
      ])

      # etcd-wrapper client params
      initial_cluster_clients = join(",", [
        for hostname, ip in var.cluster_members :
        "${hostname}=https://${ip}:${var.client_port}"
      ])
      healthcheck_interval           = "6s"
      healthcheck_fail_count_allowed = 16
      backup_resource                = var.s3_backup_resource
      backup_interval                = "15m"
      etcd_snapshot_file             = "/var/lib/etcd/snapshot/etcd.db"
      etcd_pod_manifest_file         = "${var.static_pod_manifest_path}/etcd.json"
      static_pod_manifest_path       = var.static_pod_manifest_path
    })
  ]
}