## lldap

resource "tls_private_key" "lldap-ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "lldap-ca" {
  private_key_pem = tls_private_key.lldap-ca.private_key_pem

  validity_period_hours = 8760
  is_ca_certificate     = true

  subject {
    common_name = "lldap"
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "server_auth",
    "client_auth",
  ]
}

resource "minio_s3_bucket" "lldap" {
  bucket        = "lldap"
  force_destroy = true
}

resource "minio_iam_user" "lldap" {
  name          = "lldap"
  force_destroy = true
}

resource "minio_iam_policy" "lldap" {
  name = "lldap"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          minio_s3_bucket.lldap.arn,
          "${minio_s3_bucket.lldap.arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "lldap" {
  user_name   = minio_iam_user.lldap.id
  policy_name = minio_iam_policy.lldap.id
}

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
  ca = {
    algorithm       = tls_private_key.lldap-ca.algorithm
    private_key_pem = tls_private_key.lldap-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.lldap-ca.cert_pem
  }
  service_hostname = local.kubernetes_ingress_endpoints.lldap_http
  storage_secret   = data.terraform_remote_state.sr.outputs.lldap.storage_secret
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

  minio_endpoint          = "https://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
  minio_bucket            = minio_s3_bucket.lldap.id
  minio_access_key_id     = minio_iam_user.lldap.id
  minio_secret_access_key = minio_iam_user.lldap.secret
  minio_litestream_prefix = "$POD_NAME/litestream"
}

## authelia

resource "minio_s3_bucket" "authelia" {
  bucket        = "authelia"
  force_destroy = true
}

resource "minio_iam_user" "authelia" {
  name          = "authelia"
  force_destroy = true
}

resource "minio_iam_policy" "authelia" {
  name = "authelia"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          minio_s3_bucket.authelia.arn,
          "${minio_s3_bucket.authelia.arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "authelia" {
  user_name   = minio_iam_user.authelia.id
  policy_name = minio_iam_policy.authelia.id
}

module "authelia" {
  source    = "./modules/authelia"
  name      = local.kubernetes_services.authelia.name
  namespace = local.kubernetes_services.authelia.namespace
  helm_template = {
    repository = "https://charts.authelia.com"
    chart      = "authelia"
    version    = "0.10.17"
  }
  images = {
    litestream = local.container_images.litestream
    keydb      = local.container_images.keydb
  }
  service_hostname = local.kubernetes_ingress_endpoints.auth
  lldap_ca = {
    algorithm       = tls_private_key.lldap-ca.algorithm
    private_key_pem = tls_private_key.lldap-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.lldap-ca.cert_pem
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
        address       = "submission://${var.smtp.host}:${var.smtp.port}"
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

  minio_endpoint          = "https://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
  minio_bucket            = minio_s3_bucket.authelia.id
  minio_litestream_prefix = "$POD_NAME/litestream"
  minio_access_key_id     = minio_iam_user.authelia.id
  minio_secret_access_key = minio_iam_user.authelia.secret
}
