locals {
  authelia_service_domain                 = join(".", slice(compact(split(".", var.service_hostname)), 1, length(compact(split(".", var.service_hostname)))))
  authelia_redis_client_cert_path = "/custom/redis-client-cert.pem"
  authelia_redis_client_key_path  = "/custom/redis-client-key.pem"
  authelia_users_file_path = "/config/users_database.yml"

  authelia_db_user    = "authelia"
  authelia_db_service = "yb-tserver-service"
  authelia_ns         = "authelia"
}

resource "random_password" "authelia-storage-secret" {
  length  = 64
  special = false
}

resource "random_password" "authelia-session-encryption-key" {
  length  = 128
  special = false
}

resource "random_password" "authelia-jwt-token" {
  length  = 128
  special = false
}

resource "random_password" "authelia-oidc-hmac" {
  length  = 64
  special = false
}

resource "random_string" "authelia-db-password" {
  length  = 32
  special = false
}

resource "tls_private_key" "authelia-redis-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_self_signed_cert" "authelia-redis-ca" {
  private_key_pem = tls_private_key.authelia-redis-ca.private_key_pem

  validity_period_hours = 8760
  is_ca_certificate     = true

  subject {
    common_name = var.name
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "server_auth",
    "client_auth",
  ]
}

resource "tls_private_key" "authelia-redis-client" {
  algorithm   = tls_private_key.authelia-redis-ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = 4096
}

resource "tls_cert_request" "authelia-redis-client" {
  private_key_pem = tls_private_key.authelia-redis-client.private_key_pem

  subject {
    common_name = "keydb"
  }
}

resource "tls_locally_signed_cert" "authelia-redis-client" {
  cert_request_pem   = tls_cert_request.authelia-redis-client.cert_request_pem
  ca_private_key_pem = tls_private_key.authelia-redis-ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.authelia-redis-ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

resource "tls_private_key" "authelia-oidc-jwk-ca" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "tls_self_signed_cert" "authelia-oidc-jwk-ca" {
  private_key_pem = tls_private_key.authelia-oidc-jwk-ca.private_key_pem

  validity_period_hours = 8760
  is_ca_certificate     = true

  subject {
    common_name = var.name
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "server_auth",
    "client_auth",
  ]
}

module "secret" {
  source  = "../../../modules/secret"
  name    = "${var.name}-custom"
  app     = var.name
  release = var.helm_template.version
  data = {
    basename(local.authelia_redis_client_cert_path) = tls_locally_signed_cert.authelia-redis-client.cert_pem
    basename(local.authelia_redis_client_key_path)  = tls_private_key.authelia-redis-client.private_key_pem
  }
}

# redis #

module "authelia-keydb" {
  source    = "../keydb"
  name      = "authelia-redis"
  namespace = var.namespace
  release   = var.helm_template.version
  replicas  = var.redis_replicas
  images = {
    keydb = var.images.keydb
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

resource "helm_release" "authelia-keydb" {
  chart            = "../helm-wrapper"
  name             = module.authelia-keydb.name
  namespace        = module.authelia-keydb.namespace
  create_namespace = true
  wait             = true
  wait_for_jobs             = true
  timeout          = 300
  max_history      = 2
  values = [
    yamlencode({
      manifests = module.authelia-keydb.manifests
    }),
  ]
}

# ysql #

resource "helm_release" "authelia-db" {
  name             = "authelia-db"
  repository       = "https://charts.yugabyte.com"
  chart            = "yugabyte"
  namespace        = local.authelia_ns
  create_namespace = true
  wait             = true
  wait_for_jobs    = true
  version          = "2024.2.3"
  max_history      = 2
  values = [
    yamlencode({
      # overrides https://github.com/yugabyte/charts/blob/master/stable/yugabyte/values.yaml
      replicas = {
        master  = 3
        tserver = 3
      }
      domainName = local.domains.kubernetes
      resource = {
        master = {
          requests = {
            cpu    = "200m"
            memory = "200Mi"
          }
        }
        tserver = {
          requests = {
            cpu    = "400m"
            memory = "400Mi"
          }
        }
      }
      serviceEndpoints = [
        {
          name = local.authelia_db_service
          type = "LoadBalancer"
          annotations = {
            "kube-vip.io/loadbalancerIPs" = "0.0.0.0"
          }
          app = "yb-tserver"
          ports = {
            tcp-ysql-port = local.service_ports.yugabyte_ysql
          },
        },
      ]
      authCredentials = {
        ysql = {
          user     = local.authelia_db_user
          password = random_string.authelia-db-password.result
        }
      }
    }),
  ]
}

# authelia #

resource "helm_release" "authelia" {
  name       = var.name
  namespace  = var.namespace
  repository = var.helm_template.repository
  chart      = var.helm_template.chart
  version    = var.helm_template.version
  values = [
    yamlencode({
      service = {
        type = "ClusterIP"
      }
      ingress = {
        enabled = true
        annotations = {
          "cert-manager.io/cluster-issuer" = var.ingress_cert_issuer
        }
        certManager = true
        className   = var.ingress_class_name
        tls = {
          enabled = true
          secret  = "${local.authelia_service_domain}-tls"
        }
      }
      pod = {
        replicas = 1
        kind     = "StatefulSet"
        annotations = {
          "checksum/secret-custom"     = sha256(module.secret.manifest)
        }
        extraVolumeMounts = [
          {
            name      = "secret-custom"
            mountPath = local.authelia_redis_client_key_path
            subPath   = basename(local.authelia_redis_client_key_path)
          },
          {
            name      = "secret-custom"
            mountPath = local.authelia_redis_client_cert_path
            subPath   = basename(local.authelia_redis_client_cert_path)
          },
        ]
        extraVolumes = [
          {
            name = "secret-custom"
            secret = {
              secretName = module.secret.name
            }
          },
        ]
        env = [
          {
            name  = "AUTHELIA_SESSION_REDIS_TLS_PRIVATE_KEY_FILE"
            value = local.redis_client_key_path
          },
          {
            name  = "AUTHELIA_SESSION_REDIS_TLS_CERTIFICATE_CHAIN_FILE"
            value = local.redis_client_cert_path
          },
        ]
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
        identity_providers = {
          oidc = {
            hmac_secret = {
              value = random_password.authelia-oidc-hmac.result
            }
            jwks = [
              {
                key_id    = var.name
                algorithm = "RS256"
                use       = "sig"
                certificate_chain = {
                  value = tls_self_signed_cert.authelia-oidc-jwk-ca.cert_pem
                }
                key = {
                  value = tls_private_key.authelia-oidc-jwk-ca.private_key_pem
                }
              },
            ]
          }
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
          }
          file = {
            enabled = true
            watch = true
            path = local.authelia_users_file_path
            search = {
              email = true
            }
          }
        }
        session = {
          cookies = {
            domain    = local.authelia_service_domain
            subdomain = compact(split(".", var.service_hostname))[0]
          }
          inactivity  = "4h"
          expiration  = "4h"
          remember_me = 0
          encryption_key = {
            value = data.terraform_remote_state.sr.outputs.authelia.session_encryption_key
          }
          redis = {
            enabled = true
            deploy  = false
            host    = "${var.name}-redis.${var.namespace}"
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
          postgres = {
            enabled = true
            address = "tcp://${local.authelia_db_service}.${local.authelia_ns}:${local.service_ports.yugabyte_ysql}"
            username = local.authelia_db_user
            password = {
              value = random_string.authelia-db-password.result
            }
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
        }
      }
      secret = var.secret
      certificates = {
        values = [
          {
            name  = "redis-ca.pem"
            value = tls_self_signed_cert.authelia-redis-ca.cert_pem
          },
        ]
      }
      persistence = {
        enabled = false
      }
    }),
  ]
  depends_on = [
    helm_release.authelia-keydb,
    helm_release.authelia-db,
  ]
}