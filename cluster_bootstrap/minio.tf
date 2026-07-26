resource "random_password" "minio-access-key-id" {
  length  = 30
  special = false
}

resource "random_password" "minio-secret-access-key" {
  length  = 30
  special = false
}

module "minio" {
  source    = "./modules/minio_release"
  name      = local.endpoints.minio.name
  namespace = local.endpoints.minio.namespace
  timeout   = local.kubernetes.helm_release_timeout
  images = {
    minio = local.container_images_digest.minio
  }
  service_port = local.service_ports.minio
  root_user = {
    id     = random_password.minio-access-key-id.result
    secret = random_password.minio-secret-access-key.result
  }
  ca_issuer_name   = local.kubernetes.cert_issuers.ca_internal
  service_hostname = local.endpoints.minio.service
  service_ip       = local.endpoints.minio.service_ip

  depends_on = [
    kubernetes_labels.labels,
    helm_release.cert-manager-crds,
    helm_release.prometheus-operator-crds,
  ]
}