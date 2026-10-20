resource "random_password" "etcd-snapshot-encryption-key" {
  length           = 32
  override_special = "-_"
}

module "etcd" {
  for_each = local.members.etcd
  source   = "./modules/etcd"

  butane_version = local.butane_version
  fw_mark        = local.fw_marks.accept
  name           = local.services.etcd.name
  namespace      = local.services.etcd.namespace
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
    etcd = {
      repository = "registry.k8s.io/etcd"
      tag        = "v3.7.2@sha256:7c6c239825d00e3f6328a69caafd54be92063acf0c2ce78b8394699f52b75dc3" # renovate: datasource=docker depName=registry.k8s.io/etcd
    }
    etcd-wrapper = {
      repository = "ghcr.io/randomcoww/etcd-wrapper"
      tag        = "v0.6.5@sha256:a8007f0627d585e26da29553dd81a99dd6dcdee5f2889b5154b05f0511a04e6e" # renovate: datasource=docker depName=ghcr.io/randomcoww/etcd-wrapper
    }
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
  s3_endpoint             = "https://${data.terraform_remote_state.sr.outputs.r2_bucket.etcd.url}"
  s3_bucket               = data.terraform_remote_state.sr.outputs.r2_bucket.etcd.bucket
  s3_resource_prefix      = "${local.kubernetes.cluster_name}/snapshot-"
  s3_access_key_id        = data.terraform_remote_state.sr.outputs.r2_bucket.etcd.access_key_id
  s3_secret_access_key    = data.terraform_remote_state.sr.outputs.r2_bucket.etcd.secret_access_key
  snapshot_encryption_key = random_password.etcd-snapshot-encryption-key.result
  config_base_path        = local.kubernetes.kubernetes_config_path
  static_pod_path         = local.kubernetes.static_pod_manifest_path
  data_storage_path       = "${local.kubernetes.containers_path}/etcd"
}