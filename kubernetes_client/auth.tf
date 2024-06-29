resource "tls_private_key" "authelia-redis-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_self_signed_cert" "authelia-redis-ca" {
  private_key_pem = tls_private_key.authelia-redis-ca.private_key_pem

  validity_period_hours = 8760
  is_ca_certificate     = true

  subject {
    common_name  = "redis"
    organization = "redis"
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "server_auth",
    "client_auth",
  ]
}

module "authelia-redis" {
  source    = "./modules/keydb"
  name      = local.kubernetes_services.authelia_redis.name
  namespace = local.kubernetes_services.authelia_redis.namespace
  release   = "0.1.0"
  replicas  = 3
  images = {
    keydb = local.container_images.keydb
  }
  ports = {
    keydb = local.service_ports.redis
  }
  ca = {
    algorithm       = tls_private_key.authelia-redis-ca.algorithm
    private_key_pem = tls_private_key.authelia-redis-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.authelia-redis-ca.cert_pem
  }
  cluster_service_endpoint = local.kubernetes_services.authelia_redis.fqdn
}

module "authelia" {
  source         = "./modules/authelia"
  name           = local.kubernetes_services.authelia.name
  namespace      = local.kubernetes_services.authelia.namespace
  source_release = "0.8.58"
  images = {
    litestream = local.container_images.litestream
  }
  service_hostname = local.kubernetes_ingress_endpoints.auth
  lldap_ca         = data.terraform_remote_state.sr.outputs.lldap.ca
  redis_ca = {
    algorithm       = tls_private_key.authelia-redis-ca.algorithm
    private_key_pem = tls_private_key.authelia-redis-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.authelia-redis-ca.cert_pem
  }
  configmap = {
    telemetry = {
      metrics = {
        enabled = false
      }
    }
    default_redirection_url = "https://${local.kubernetes_ingress_endpoints.auth}"
    default_2fa_method      = "totp"
    theme                   = "dark"
    totp = {
      disable = false
    }
    webauthn = {
      disable = true
    }
    duo_api = {
      disable = true
    }
    authentication_backend = {
      password_reset = {
        disable    = true
        custom_url = "https://${local.kubernetes_ingress_endpoints.lldap_http}/reset-password/step1"
      }
      # https://github.com/lldap/lldap/blob/main/example_configs/authelia_config.yml
      ldap = {
        enabled        = true
        implementation = "custom"
        tls = {
          enabled         = true
          skip_verify     = false
          minimum_version = "TLS1.3"
        }
        url                    = "ldaps://${local.kubernetes_services.lldap.endpoint}:${local.service_ports.lldap}"
        base_dn                = "dc=${join(",dc=", slice(compact(split(".", local.kubernetes_ingress_endpoints.lldap_http)), 1, length(compact(split(".", local.kubernetes_ingress_endpoints.lldap_http)))))}"
        username_attribute     = "uid"
        additional_users_dn    = "ou=people"
        users_filter           = "(&({username_attribute}={input})(objectClass=person))"
        additional_groups_dn   = "ou=groups"
        groups_filter          = "(member={dn})"
        group_name_attribute   = "cn"
        mail_attribute         = "mail"
        display_name_attribute = "displayName"
        user                   = "uid=${data.terraform_remote_state.sr.outputs.lldap.user},ou=people,dc=${join(",dc=", slice(compact(split(".", local.kubernetes_ingress_endpoints.lldap_http)), 1, length(compact(split(".", local.kubernetes_ingress_endpoints.lldap_http)))))}"
      }
      file = {
        enabled = false
      }
    }
    session = {
      inactivity           = "4h"
      expiration           = "4h"
      remember_me_duration = 0
      redis = {
        enabled = true
        host    = local.kubernetes_services.authelia_redis.fqdn
        port    = local.service_ports.redis
        password = {
          disabled = true
        }
        tls = {
          enabled         = true
          skip_verify     = false
          minimum_version = "TLS1.3"
        }
      }
    }
    regulation = {
      max_retries = 4
    }
    notifier = {
      disable_startup_check = true
      smtp = {
        enabled       = true
        enabledSecret = true
        host          = var.smtp.host
        port          = var.smtp.port
        username      = var.smtp.username
        sender        = var.smtp.username
      }
    }
    access_control = {
      default_policy = "two_factor"
      rules = [
        {
          domain    = local.kubernetes_ingress_endpoints.vaultwarden
          resources = ["^/admin.*"]
          policy    = "two_factor"
        },
        {
          domain = local.kubernetes_ingress_endpoints.vaultwarden
          policy = "bypass"
        },
      ]
    }
  }
  secret = {
    jwt = {
      value = data.terraform_remote_state.sr.outputs.authelia.jwt_token
    }
    storageEncryptionKey = {
      value = data.terraform_remote_state.sr.outputs.authelia.storage_secret
    }
    session = {
      value = data.terraform_remote_state.sr.outputs.authelia.session_encryption_key
    }
    smtp = {
      value = var.smtp.password
    }
    ldap = {
      value = data.terraform_remote_state.sr.outputs.lldap.password
    }
  }
  ingress_class_name  = local.ingress_classes.ingress_nginx_external
  ingress_cert_issuer = local.kubernetes.cert_issuer_prod

  litestream_s3_resource             = data.terraform_remote_state.sr.outputs.s3.authelia.resource
  litestream_s3_access_key_id        = data.terraform_remote_state.sr.outputs.s3.authelia.access_key_id
  litestream_s3_secret_access_key    = data.terraform_remote_state.sr.outputs.s3.authelia.secret_access_key
  litestream_minio_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  litestream_minio_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  litestream_minio_bucket            = local.minio_buckets.litestream.name
  litestream_minio_endpoint          = "${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
}

# LDAP

module "lldap" {
  source    = "./modules/lldap"
  name      = local.kubernetes_services.lldap.name
  namespace = local.kubernetes_services.lldap.namespace
  release   = "0.1.0"
  images = {
    lldap      = local.container_images.lldap
    litestream = local.container_images.litestream
  }
  ports = {
    lldap_ldaps = local.service_ports.lldap
  }
  ca                       = data.terraform_remote_state.sr.outputs.lldap.ca
  cluster_service_endpoint = local.kubernetes_services.lldap.fqdn
  service_hostname         = local.kubernetes_ingress_endpoints.lldap_http
  storage_secret           = data.terraform_remote_state.sr.outputs.lldap.storage_secret
  extra_configs = {
    LLDAP_VERBOSE                             = true
    LLDAP_JWT_SECRET                          = data.terraform_remote_state.sr.outputs.lldap.jwt_token
    LLDAP_LDAP_USER_DN                        = data.terraform_remote_state.sr.outputs.lldap.user
    LLDAP_LDAP_USER_PASS                      = data.terraform_remote_state.sr.outputs.lldap.password
    LLDAP_SMTP_OPTIONS__ENABLE_PASSWORD_RESET = true
    LLDAP_SMTP_OPTIONS__SERVER                = var.smtp.host
    LLDAP_SMTP_OPTIONS__PORT                  = var.smtp.port
    LLDAP_SMTP_OPTIONS__SMTP_ENCRYPTION       = "STARTTLS"
    LLDAP_SMTP_OPTIONS__USER                  = var.smtp.username
    LLDAP_SMTP_OPTIONS__PASSWORD              = var.smtp.password
    LLDAP_LDAPS_OPTIONS__ENABLED              = true
  }
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations

  litestream_s3_resource             = data.terraform_remote_state.sr.outputs.s3.lldap.resource
  litestream_s3_access_key_id        = data.terraform_remote_state.sr.outputs.s3.lldap.access_key_id
  litestream_s3_secret_access_key    = data.terraform_remote_state.sr.outputs.s3.lldap.secret_access_key
  litestream_minio_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  litestream_minio_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  litestream_minio_bucket            = local.minio_buckets.litestream.name
  litestream_minio_endpoint          = "${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
}

# Vaultwarden

module "vaultwarden" {
  source    = "./modules/vaultwarden"
  name      = "vaultwarden"
  namespace = "vaultwarden"
  release   = "0.1.14"
  images = {
    vaultwarden = local.container_images.vaultwarden
    litestream  = local.container_images.litestream
  }
  service_hostname = local.kubernetes_ingress_endpoints.vaultwarden
  extra_configs = {
    SENDS_ALLOWED            = false
    EMERGENCY_ACCESS_ALLOWED = false
    PASSWORD_HINTS_ALLOWED   = false
    SIGNUPS_ALLOWED          = false
    INVITATIONS_ALLOWED      = true
    DISABLE_ADMIN_TOKEN      = true
    SMTP_USERNAME            = var.smtp.username
    SMTP_FROM                = var.smtp.username
    SMTP_PASSWORD            = var.smtp.password
    SMTP_HOST                = var.smtp.host
    SMTP_PORT                = var.smtp.port
    SMTP_FROM_NAME           = "Vaultwarden"
    SMTP_SECURITY            = "starttls"
    SMTP_AUTH_MECHANISM      = "Plain"
  }
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations

  litestream_s3_resource             = data.terraform_remote_state.sr.outputs.s3.vaultwarden.resource
  litestream_s3_access_key_id        = data.terraform_remote_state.sr.outputs.s3.vaultwarden.access_key_id
  litestream_s3_secret_access_key    = data.terraform_remote_state.sr.outputs.s3.vaultwarden.secret_access_key
  litestream_minio_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  litestream_minio_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  litestream_minio_bucket            = local.minio_buckets.litestream.name
  litestream_minio_endpoint          = "${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
}