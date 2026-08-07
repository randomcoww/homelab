locals {
  lldap_name      = "lldap"
  lldap_namespace = "auth"
  lldap_port      = 6360
}

resource "random_password" "lldap-user" {
  length  = 30
  special = false
}

resource "random_password" "lldap-password" {
  length  = 30
  special = false
}

module "lldap" {
  source         = "./modules/lldap"
  name           = local.lldap_name
  namespace      = local.lldap_namespace
  service_domain = local.domains.kubernetes # needs fqdn
  images = {
    lldap = {
      repository = "ghcr.io/lldap/lldap"
      tag        = "v0.6.3-alpine-rootless@sha256:ba2c50930ea998eefd5454aa678a7977448019248b1827da87d330df0b71c284" # renovate: datasource=docker depName=ghcr.io/lldap/lldap
    }
  }
  extra_envs = {
    LLDAP_LDAPS_OPTIONS__PORT                 = local.lldap_port
    LLDAP_VERBOSE                             = true
    LLDAP_LDAP_USER_DN                        = random_password.lldap-user.result
    LLDAP_LDAP_USER_PASS                      = random_password.lldap-password.result
    LLDAP_SMTP_OPTIONS__ENABLE_PASSWORD_RESET = true
    LLDAP_SMTP_OPTIONS__SERVER                = var.smtp_host
    LLDAP_SMTP_OPTIONS__PORT                  = var.smtp_port
    LLDAP_SMTP_OPTIONS__SMTP_ENCRYPTION       = "STARTTLS"
    LLDAP_SMTP_OPTIONS__USER                  = var.smtp_username
    LLDAP_SMTP_OPTIONS__PASSWORD              = var.smtp_password
  }
  ca_issuer_name   = local.cert_issuers.ca_internal
  ingress_hostname = local.httproutes.lldap.hostname
  gateway_ref = {
    name      = local.services.cilium.name
    namespace = local.services.cilium.namespace
  }
}

resource "minio_s3_object" "fluxcd-lldap" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.lldap.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "lldap/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}

# lldap admin

output "lldap" {
  value = {
    dn   = random_password.lldap-user.result
    pass = random_password.lldap-password.result
  }
  sensitive = true
}