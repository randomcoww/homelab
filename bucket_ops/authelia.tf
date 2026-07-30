locals {
  # OIDC clients
  authelia_oidc_claims_policies = {
    stump_policy = {
      id_token = [
        "email",
        "name",
      ]
    }
  }

  authelia_oidc_clients_base = {
    stump = {
      client_name = "Stump"
      scopes = [
        "openid",
        "email",
        "profile",
      ]
      require_pkce          = false
      pkce_challenge_method = ""
      redirect_uris = [
        "https://${local.endpoints.stump.ingress}/api/v2/auth/oidc/callback",
      ]
      claims_policy = "stump_policy"
      consent_mode  = "implicit"
    }
    hermes-dashboard = {
      client_name = "hermes-dashboard"
      scopes = [
        "openid",
        "email",
        "profile",
      ]
      require_pkce          = false
      pkce_challenge_method = ""
      redirect_uris = [
        "https://${local.endpoints.hermes_agent.ingress}/auth/callback",
      ]
      consent_mode = "implicit"
    }
  }

  authelia_oidc_clients = {
    for k, v in local.authelia_oidc_clients_base :
    k => merge(v, {
      client_id     = random_string.authelia-oidc-client-id[k].result
      client_secret = random_password.authelia-oidc-client-secret[k].result
    })
  }
}

resource "random_string" "authelia-oidc-client-id" {
  for_each = local.authelia_oidc_clients_base

  length  = 32
  special = false
  upper   = false
}

resource "random_password" "authelia-oidc-client-secret" {
  for_each = local.authelia_oidc_clients_base

  length  = 32
  special = false
}

module "authelia-valkey" {
  source    = "./modules/valkey"
  name      = local.endpoints.authelia_valkey.name
  namespace = local.endpoints.authelia_valkey.namespace
  images = {
    valkey = local.container_images_digest.valkey
  }
  service_port     = local.service_ports.redis_sentinel
  service_hostname = local.endpoints.authelia_valkey.service_fqdn
  ca_issuer_name   = local.cert_issuers.ca_internal
}

module "authelia" {
  source    = "./modules/authelia"
  name      = local.endpoints.authelia.name
  namespace = local.endpoints.authelia.namespace
  images = {
    authelia = {
      registry   = regex(local.container_image_regex, local.container_images.authelia).repository
      repository = regex(local.container_image_regex, local.container_images.authelia).image
      tag        = regex(local.container_image_regex, local.container_images.authelia).tag
    }
  }
  ca_issuer_name = local.cert_issuers.ca_internal
  ldap_endpoint  = "${local.endpoints.lldap.service_fqdn}:${local.service_ports.ldaps}"
  redis_sentinel_endpoint = {
    host        = local.endpoints.authelia_valkey.service_fqdn
    port        = local.service_ports.redis_sentinel
    master_name = local.endpoints.authelia_valkey.name
  }
  smtp = {
    host     = var.smtp_host
    port     = var.smtp_port
    username = var.smtp_username
    password = var.smtp_password
  }
  ldap_credentials = {
    username = random_password.lldap-user.result
    password = random_password.lldap-password.result
  }
  oidc_clients         = local.authelia_oidc_clients
  oidc_claims_policies = local.authelia_oidc_claims_policies

  ingress_hostname = local.endpoints.authelia.ingress
  gateway_ref = {
    name      = local.endpoints.cilium.name
    namespace = local.endpoints.cilium.namespace
  }

  reference_grant_namespaces = [
    "default",
  ]
}

resource "minio_s3_object" "fluxcd-authelia" {
  for_each = {
    "manifest.yaml" = join("\n---\n", distinct(concat(module.authelia-valkey.manifests, module.authelia.manifests)))
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "authelia/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}