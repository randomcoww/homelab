locals {
  certs_path = "/var/lib/etcd"

  certs = {
    etcd = {
      ca_cert = {
        path    = "${local.certs_path}/ca.pem"
        content = var.kubernetes_ca.cert_pem
      }
    }
  }

  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      etcd_container_image         = etcd_container_image
      etcd_wrapper_container_image = etcd_wrapper_container_image
      host_netnum                  = var.host_netnum
      network_prefix               = var.network_prefix
      certs                        = local.certs.etcd
      certs_path                   = local.certs_path
      static_pod_manifest_path     = "/var/lib/kubelet/manifests"
      static_pod_config_path       = "/var/lib/kubelet/podconfig"
      etcd_hosts                   = var.etcd_hosts
      etcd_cluster_token           = var.etcd_cluster_token
      etcd_client_port             = var.etcd_client_port
      etcd_peer_port               = var.etcd_peer_port

      aws_access_key_id     = var.aws_access_key_id
      aws_secret_access_key = var.aws_secret_access_key
      aws_region            = var.aws_region
      etcd_s3_backup_bucket = var.etcd_s3_backup_bucket
    })
  ]
}