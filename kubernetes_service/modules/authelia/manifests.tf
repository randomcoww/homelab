locals {
  authelia_db_file                 = "/config/db.sqlite3" # base path not configurable
  authelia_litestream_config_file  = "/etc/litestream/config.yaml"
  authelia_client_tls_cert_file    = "/custom/client-cert.pem"
  authelia_client_tls_key_file     = "/custom/client-key.pem"
  authelia_oidc_jwk_key_file       = "/custom/oidc-jwk-key.pem"
  authelia_oidc_hmac_secret_file   = "/custom/oidc-hmac-secret"
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
  for_each = var.authelia_oidc_clients

  length  = 32
  special = false
  upper   = false
}

resource "random_password" "authelia-oidc-client-secret" {
  for_each = var.authelia_oidc_clients

  length  = 32
  special = false
}

module "secret" {
  source  = "../../../modules/secret"
  name    = "${var.name}-secret-custom"
  app     = var.name
  release = var.release
  data = merge({
    "litestream" = yamlencode({
      dbs = [
        {
          path                = local.authelia_db_file
          monitor-interval    = "1s"
          checkpoint-interval = "60s"
          replica = {
            type          = "s3"
            endpoint      = "https://${var.minio_endpoint}"
            bucket        = var.minio_bucket
            path          = "$POD_NAME/litestream"
            sync-interval = "1s"
            part-size     = "50MB"
            concurrency   = 10
          }
        },
      ]
    })
    "oidc-jwk-key"     = tls_private_key.authelia-oidc-jwk.private_key_pem
    "oidc-hmac-secret" = random_password.authelia-oidc-hmac-secret.result
    }, {
    # clients
    for key, v in var.authelia_oidc_clients :
    "oidc-client-id-${key}" => v.client_id
    }, {
    for key, v in var.authelia_oidc_clients :
    "oidc-client-secret-${key}" => v.client_secret
  })
}