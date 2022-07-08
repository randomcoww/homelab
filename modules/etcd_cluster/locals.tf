locals {
  ca = {
    algorithm       = tls_private_key.etcd-ca.algorithm
    private_key_pem = tls_private_key.etcd-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.etcd-ca.cert_pem
  }
  peer_ca = {
    algorithm       = tls_private_key.etcd-peer-ca.algorithm
    private_key_pem = tls_private_key.etcd-peer-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.etcd-peer-ca.cert_pem
  }

  certs = {
    ca_cert = {
      content = tls_self_signed_cert.etcd-ca.cert_pem
    }
    peer_ca_cert = {
      content = tls_self_signed_cert.etcd-peer-ca.cert_pem
    }
  }

  s3_backup_path = "${var.s3_backup_bucket}/${var.cluster_token}"

  cluster_endpoints = [
    for host in var.cluster_hosts :
    "https://${host.client_ip}:${host.client_port}"
  ]

  initial_cluster = [
    for host in var.cluster_hosts :
    "${host.hostname}=https://${host.peer_ip}:${host.peer_port}"
  ]
}