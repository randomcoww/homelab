# Kavita

module "kavita" {
  source    = "./modules/kavita"
  name      = local.endpoints.kavita.name
  namespace = local.endpoints.kavita.namespace
  release   = "0.1.0"
  replicas  = 1
  images = {
    kavita     = local.container_images.kavita
    mountpoint = local.container_images.mountpoint
    litestream = local.container_images.litestream
  }
  extra_configs = {
    OpenIdConnectSettings = {
      Authority    = "https://${local.endpoints.authelia.ingress}"
      ClientId     = random_string.authelia-oidc-client-id["kavita"].result
      Secret       = random_password.authelia-oidc-client-secret["kavita"].result
      CustomScopes = []
      Enabled      = true
    }
  }
  ingress_hostname = local.endpoints.kavita.ingress
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
  minio_endpoint      = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_data_bucket   = "ebooks"
  minio_bucket        = "kavita"
  minio_access_secret = local.minio_users.kavita.secret
}