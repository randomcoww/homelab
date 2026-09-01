locals {
  authelia_name      = "authelia"
  authelia_namespace = "auth"

  # OIDC clients
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
        "https://${local.endpoints.stump.hostname}/api/v2/auth/oidc/callback",
      ]
      claims_policy = "stump_policy" # defined and used under oidc_claims_policies
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
        "https://${local.endpoints.hermes-agent.hostname}/auth/callback",
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

module "authelia" {
  source    = "./modules/authelia"
  name      = local.authelia_name
  namespace = local.authelia_namespace
  images = {
    authelia = {
      registry   = "ghcr.io/authelia"
      repository = "authelia"
      tag        = "4.39.20@sha256:1b363e9279e742397966333f364e0876ae02bf5c876de73e83af6d48c57ff51b" # renovate: datasource=docker depName=ghcr.io/authelia/authelia
    }
  }
  ca_issuer_name = local.cert_issuers.ca_internal
  ldap_endpoint  = "${local.lldap_name}.${local.lldap_namespace}.svc.${local.domains.kubernetes}:${local.lldap_port}" # needs fqdn
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
  oidc_clients = local.authelia_oidc_clients
  oidc_claims_policies = {
    stump_policy = {
      id_token = [
        "email",
        "name",
      ]
    }
  }

  ingress_hostname = local.endpoints.authelia.hostname
  gateway_ref = {
    name      = local.services.cilium.name
    namespace = local.services.cilium.namespace
  }

  reference_grant_namespaces = [
    "default",
    "hostnet",
    "ai",
  ]
}

resource "minio_s3_object" "fluxcd-authelia" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.authelia.manifests)
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