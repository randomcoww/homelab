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
  name      = local.endpoints.minio.name
  namespace = local.endpoints.minio.namespace
  timeout   = local.kubernetes.helm_release_timeout
  images = {
    minio = {
      repository = "cgr.dev/chainguard/minio"
      tag        = "latest@sha256:5f2b82fe2edccafed7902f423f171ae5e6b8b363fae72441c0e0e4289dc45555" # renovate: datasource=docker depName=cgr.dev/chainguard/minio
    }
  }
  service_port = local.service_ports.minio
  root_user = {
    id     = random_password.minio-access-key-id.result
    secret = random_password.minio-secret-access-key.result
  }
  ca               = data.terraform_remote_state.host.outputs.internal_ca
  service_hostname = local.endpoints.minio.service
  service_ip       = local.endpoints.minio.service_ip

  depends_on = [
    kubernetes_labels.labels,
    helm_release.cert-manager-crds,
    helm_release.prometheus-operator-crds,
  ]
}

output "minio" {
  value = {
    access_key_id     = random_password.minio-access-key-id.result
    secret_access_key = random_password.minio-secret-access-key.result
  }
  sensitive = true
}