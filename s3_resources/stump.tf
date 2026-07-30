module "stump" {
  source    = "./modules/stump"
  name      = local.endpoints.stump.name
  namespace = local.endpoints.stump.namespace
  replicas  = 1
  images = {
    stump      = local.container_images_digest.stump
    litestream = local.container_images_digest.litestream
  }
  extra_configs = {
    STUMP_OIDC_ISSUER_URL    = "https://${local.endpoints.authelia.ingress}"
    STUMP_OIDC_CLIENT_ID     = local.authelia_oidc_clients.stump.client_id
    STUMP_OIDC_CLIENT_SECRET = local.authelia_oidc_clients.stump.client_secret
    STUMP_OIDC_SCOPES        = join(",", local.authelia_oidc_clients.stump.scopes)
  }
  ingress_hostname = local.endpoints.stump.ingress
  gateway_ref = {
    name      = local.endpoints.cilium.name
    namespace = local.endpoints.cilium.namespace
  }
  minio_endpoint    = "https://${local.endpoints.minio.service}:${local.service_ports.minio}"
  minio_data_bucket = "ebooks"
  minio_bucket      = "stump"
  minio_user        = minio_iam_user.user["stump"]
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
    minio_s3_bucket.bucket["fluxcd"],
  ]
}