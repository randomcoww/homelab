locals {
  envs = {
    AUTHELIA_AUTHENTICATION_BACKEND_LDAP_TLS_PRIVATE_KEY_FILE       = "/custom/ldap-client-key.pem"
    AUTHELIA_AUTHENTICATION_BACKEND_LDAP_TLS_CERTIFICATE_CHAIN_FILE = "/custom/ldap-client-cert.pem"
    AUTHELIA_SESSION_REDIS_TLS_PRIVATE_KEY_FILE                     = "/custom/redis-client-key.pem"
    AUTHELIA_SESSION_REDIS_TLS_CERTIFICATE_CHAIN_FILE               = "/custom/redis-client-cert.pem"
    AUTHELIA_STORAGE_POSTGRES_PASSWORD_FILE                         = "/custom/posgres-password"
    AUTHELIA_IDENTITY_PROVIDERS_OIDC_HMAC_SECRET_FILE               = "/custom/oidc-hmac-secret"
  }
  authelia_oidc_jwk_key_file       = "/custom/oidc-jwk-key.pem"
  autehlia_oidc_client_shared_path = "/oidc"
  domain_regex                     = "(?<hostname>(?<subdomain>[a-z0-9-*]+)\\.(?<domain>[a-z0-9.-]+))(?::(?<port>\\d+))?"
}

resource "random_bytes" "authelia-jwt-secret" {
  length = 256
}

resource "tls_private_key" "authelia-oidc-jwk" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "random_password" "authelia-storage-secret" {
  length  = 30
  special = false
}

resource "random_password" "authelia-session-encryption-key" {
  length  = 30
  special = false
}

resource "random_password" "authelia-oidc-hmac-secret" {
  length  = 64
  special = false
}

resource "random_string" "authelia-oidc-client-id" {
  for_each = var.oidc_clients

  length  = 32
  special = false
  upper   = false
}

resource "random_password" "authelia-oidc-client-secret" {
  for_each = var.oidc_clients

  length  = 32
  special = false
}

module "secret" {
  source    = "../../../modules/secret"
  name      = "${var.name}-secret-custom"
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = merge({
    "oidc-jwk-key"     = tls_private_key.authelia-oidc-jwk.private_key_pem
    "oidc-hmac-secret" = random_password.authelia-oidc-hmac-secret.result
    }, {
    # clients
    for key, v in var.oidc_clients :
    "oidc-client-id-${key}" => v.client_id
    }, {
    for key, v in var.oidc_clients :
    "oidc-client-secret-${key}" => v.client_secret
  })
}