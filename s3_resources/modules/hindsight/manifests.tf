locals {
  postgres_database = "hindsight"
  postgres_username = "hindsight"
}

resource "random_password" "postgres-password" {
  length  = 32
  special = false
}

module "postgres-secret" {
  source    = "../../../modules/secret"
  name      = "${var.name}-cnpg"
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    # cngp params
    username = local.postgres_user
    password = random_password.postgres-password.result
  }
}