locals {
  client_tls_path   = "/etc/hindsight/tls"
  postgres_database = "hindsight"
  postgres_username = "hindsight"
}

resource "random_password" "postgres-password" {
  length  = 32
  special = false
}

module "cnpg-secret" {
  source    = "../../../modules/secret"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    # cngp params
    username = local.postgres_username
    password = random_password.postgres-password.result
  }
}