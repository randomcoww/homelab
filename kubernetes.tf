# kubernetes #
module "etcd-common" {
  source = "./modules/etcd_common"

  s3_backup_bucket = "randomcoww-etcd-backup"
  s3_backup_key    = local.kubernetes.cluster_name
}

module "kubernetes-common" {
  source = "./modules/kubernetes_common"
}

# admin client #
resource "tls_private_key" "admin" {
  algorithm   = module.kubernetes-common.ca.kubernetes.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "admin" {
  key_algorithm   = tls_private_key.admin.algorithm
  private_key_pem = tls_private_key.admin.private_key_pem

  subject {
    common_name  = "admin"
    organization = "system:masters"
  }
}

resource "tls_locally_signed_cert" "admin" {
  cert_request_pem   = tls_cert_request.admin.cert_request_pem
  ca_key_algorithm   = module.kubernetes-common.ca.kubernetes.algorithm
  ca_private_key_pem = module.kubernetes-common.ca.kubernetes.private_key_pem
  ca_cert_pem        = module.kubernetes-common.ca.kubernetes.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

output "kubeconfig_admin" {
  value = nonsensitive(templatefile("./templates/kubeconfig_admin.yaml", {
    cluster_name       = local.kubernetes.cluster_name
    ca_pem             = module.kubernetes-common.ca.kubernetes.cert_pem
    private_key_pem    = tls_private_key.admin.private_key_pem
    cert_pem           = tls_locally_signed_cert.admin.cert_pem
    apiserver_endpoint = "https://${cidrhost(local.networks.lan.prefix, local.aio_hostclass_config.vrrp_netnum)}:${local.ports.apiserver}"
  }))
}