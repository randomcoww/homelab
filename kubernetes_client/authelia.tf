resource "tls_private_key" "authelia-redis-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_self_signed_cert" "authelia-redis-ca" {
  private_key_pem = tls_private_key.authelia-redis-ca.private_key_pem

  validity_period_hours = 8760
  is_ca_certificate     = true

  subject {
    common_name = "authelia"
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
  source                   = "./modules/keydb"
  cluster_service_endpoint = local.kubernetes_services.authelia_redis.fqdn
  release                  = "0.1.0"
  replicas                 = 2
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
}

module "authelia" {
  source         = "./modules/authelia"
  name           = local.kubernetes_services.authelia.name
  namespace      = local.kubernetes_services.authelia.namespace
  source_release = "0.9.5"
  images = {
    litestream = local.container_images.litestream
  }
  service_hostname = local.kubernetes_ingress_endpoints.auth
  lldap_ca = {
    algorithm       = tls_private_key.lldap-ca.algorithm
    private_key_pem = tls_private_key.lldap-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.lldap-ca.cert_pem
  }
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
    default_2fa_method = "totp"
    theme              = "dark"
    totp = {
      disable = false
    }
    webauthn = {
      disable = true
    }
    duo_api = {
      disable = true
    }
    identity_validation = {
      reset_password = {
        secret = {
          value = data.terraform_remote_state.sr.outputs.authelia.jwt_token
        }
      }
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
        address                = "ldaps://${local.kubernetes_services.lldap.endpoint}:${local.service_ports.lldap}"
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
        password = {
          value = data.terraform_remote_state.sr.outputs.lldap.password
        }
      }
      file = {
        enabled = false
      }
    }
    session = {
      inactivity  = "4h"
      expiration  = "4h"
      remember_me = 0
      encryption_key = {
        value = data.terraform_remote_state.sr.outputs.authelia.session_encryption_key
      }
      redis = {
        enabled = true
        deploy  = false
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
    storage = {
      encryption_key = {
        value = data.terraform_remote_state.sr.outputs.authelia.storage_secret
      }
      local = {
        enabled = true
        path    = "/config/db.sqlite3"
      }
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
        password = {
          value = var.smtp.password
        }
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