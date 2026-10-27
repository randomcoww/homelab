module "stump" {
  source    = "./modules/stump"
  name      = "stump"
  namespace = "default"
  replicas  = 1
  images = {
    stump = {
      repository = "docker.io/aaronleopold/stump"
      tag        = "0.1.11@sha256:2d62217aaabb68466d08d8f5275549ba8713b3ff5c1f39a80a742a6e66d8105b" # renovate: datasource=docker depName=docker.io/aaronleopold/stump
    }
  }
  extra_envs = {
    STUMP_OIDC_ISSUER_URL    = "https://${local.endpoints.authelia.hostname}"
    STUMP_OIDC_CLIENT_ID     = local.authelia_oidc_clients.stump.client_id
    STUMP_OIDC_CLIENT_SECRET = local.authelia_oidc_clients.stump.client_secret
    STUMP_OIDC_SCOPES        = join(",", local.authelia_oidc_clients.stump.scopes)
  }

  ca_issuer_name   = local.cert_issuers.ca_internal
  ingress_hostname = local.endpoints.stump.hostname
  gateway_ref = {
    name      = local.services.cilium.name
    namespace = local.services.cilium.namespace
  }
  minio_endpoint    = "https://${local.services.minio.name}.${local.services.minio.namespace}:${local.service_ports.minio}"
  minio_data_bucket = "ebooks"
  minio_bucket      = "stump"
}

resource "minio_s3_object" "fluxcd-stump" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.stump.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "stump/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}