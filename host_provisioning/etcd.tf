module "etcd" {
  for_each = local.members.etcd
  source   = "./modules/etcd_member"

  butane_version = local.butane_version
  fw_mark        = local.fw_marks.accept
  name           = local.endpoints.etcd.name
  namespace      = local.endpoints.etcd.namespace
  host_key       = each.key
  cluster_token  = local.kubernetes.cluster_name
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
  images = {
    etcd         = local.container_images_digest.etcd
    etcd_wrapper = local.container_images_digest.etcd_wrapper
  }
  ports = {
    etcd_client  = local.host_ports.etcd_client
    etcd_peer    = local.host_ports.etcd_peer
    etcd_metrics = local.host_ports.etcd_metrics
  }
  node_ip = cidrhost(local.networks.etcd.prefix, each.value.netnum)
  members = {
    for host_key, host in local.members.etcd :
    host_key => cidrhost(local.networks.etcd.prefix, host.netnum)
  }
  s3_resource_prefix   = "https://${data.terraform_remote_state.sr.outputs.r2_bucket.etcd.url}/${data.terraform_remote_state.sr.outputs.r2_bucket.etcd.bucket}/snapshot/${local.kubernetes.cluster_name}-"
  s3_access_key_id     = data.terraform_remote_state.sr.outputs.r2_bucket.etcd.access_key_id
  s3_secret_access_key = data.terraform_remote_state.sr.outputs.r2_bucket.etcd.secret_access_key
  static_pod_path      = local.kubernetes.static_pod_manifest_path
  data_storage_path    = "${local.kubernetes.containers_path}/etcd"
}