locals {
  client_tls_path   = "/etc/hindsight/tls"
  postgres_database = "hindsight"
  postgres_username = "hindsight"
  controlplane_port = 3000
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

module "httproute" {
  source    = "../../../modules/httproute"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  spec = {
    parentRefs = [
      merge({
        kind = "Gateway"
      }, var.gateway_ref),
    ]
    hostnames = [
      var.ingress_hostname,
    ]
    rules = [
      {
        matches = [
          {
            path = {
              type  = "PathPrefix"
              value = "/"
            }
          },
        ]
        filters = [
          {
            type = "ExternalAuth"
            externalAuth = {
              protocol   = "HTTP"
              backendRef = var.auth_backend_ref
              http = {
                path = "/api/authz/ext-authz/"
                allowedHeaders = [
                  "accept",
                  "cookie",
                  "location",
                  "authorization",
                  "proxy-authorization",
                  "x-forwarded-proto",
                ]
                allowedResponseHeaders = [
                  "Remote-User",
                  "Remote-Email",
                  "Remote-Name",
                  "Remote-Groups",
                ]
              }
            }
          },
        ]
        backendRefs = [
          {
            name = "${var.name}-control-plane"
            port = local.controlplane_port
          },
        ]
      },
    ]
  }
}
