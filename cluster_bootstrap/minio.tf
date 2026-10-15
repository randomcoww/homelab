resource "random_password" "minio-access-key-id" {
  length  = 30
  special = false
}

resource "random_password" "minio-secret-access-key" {
  length  = 30
  special = false
}

module "minio" {
  source    = "./modules/minio"
  name      = local.services.minio.name
  namespace = local.services.minio.namespace
  timeout   = local.kubernetes.helm_release_timeout
  images = {
    minio = {
      repository = "docker.io/pgsty/silo"
      tag        = "RELEASE.2026-10-15T00-00-00Z@sha256:aaac6bce13eb99316b3c88bd20143fc3c38ab607585256a411a095c44ee57f62" # renovate: datasource=docker depName=docker.io/pgsty/silo
    }
  }
  service_port = local.service_ports.minio
  root_user = {
    id     = random_password.minio-access-key-id.result
    secret = random_password.minio-secret-access-key.result
  }
  ca         = data.terraform_remote_state.host.outputs.internal_ca
  service_ip = local.networks.service.vips.minio

  depends_on = [
    kubernetes_node_taint.taints,
    helm_release.cert-manager-crds,
    helm_release.prometheus-crds,
  ]
}

output "minio" {
  value = {
    access_key_id     = random_password.minio-access-key-id.result
    secret_access_key = random_password.minio-secret-access-key.result
  }
  sensitive = true
}