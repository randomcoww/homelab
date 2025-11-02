## lldap

resource "random_password" "lldap-user" {
  length  = 30
  special = false
}

resource "random_password" "lldap-password" {
  length  = 30
  special = false
}

module "lldap" {
  source    = "./modules/lldap"
  name      = local.endpoints.lldap.name
  namespace = local.endpoints.lldap.namespace
  release   = "0.1.0"
  images = {
    lldap      = local.container_images.lldap
    litestream = local.container_images.litestream
  }
  ports = {
    ldaps = local.service_ports.ldaps
  }

  extra_configs = {
    LLDAP_VERBOSE                             = true
    LLDAP_LDAP_USER_DN                        = random_password.lldap-user.result
    LLDAP_LDAP_USER_PASS                      = random_password.lldap-password.result
    LLDAP_SMTP_OPTIONS__ENABLE_PASSWORD_RESET = true
    LLDAP_SMTP_OPTIONS__SERVER                = var.smtp.host
    LLDAP_SMTP_OPTIONS__PORT                  = var.smtp.port
    LLDAP_SMTP_OPTIONS__SMTP_ENCRYPTION       = "STARTTLS"
    LLDAP_SMTP_OPTIONS__USER                  = var.smtp.username
    LLDAP_SMTP_OPTIONS__PASSWORD              = var.smtp.password
    LLDAP_LDAPS_OPTIONS__ENABLED              = true
  }
  ca_issuer_name = local.kubernetes.cert_issuers.ca_internal

  minio_endpoint          = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket            = "lldap"
  minio_litestream_prefix = "$POD_NAME/litestream"
  minio_access_secret     = local.minio_users.lldap.secret

  service_hostname   = local.endpoints.lldap.service
  ingress_hostname   = local.endpoints.lldap.ingress
  ingress_class_name = local.endpoints.ingress_nginx.name
  nginx_ingress_annotations = merge(local.nginx_ingress_annotations_common, {
    "cert-manager.io/cluster-issuer" = local.kubernetes.cert_issuers.acme_prod
  })
  ca_bundle_configmap = local.kubernetes.ca_bundle_configmap
}

## authelia

locals {
  authelia_db_file                 = "/config/db.sqlite3" # base path not configurable
  authelia_litestream_config_file  = "/etc/litestream/config.yaml"
  authelia_client_tls_secret_name  = "${local.endpoints.authelia.name}-tls"
  authelia_client_tls_cert_file    = "/custom/client-cert.pem"
  authelia_client_tls_key_file     = "/custom/client-key.pem"
  authelia_oidc_jwk_key_file       = "/custom/oidc-jwk-key.pem"
  authelia_oidc_hmac_secret_file   = "/custom/oidc-hmac-secret"
  autehlia_oidc_client_shared_path = "/oidc"

  authelia_oidc_clients = {
    open-webui = {
      client_name           = "Open WebUI"
      require_pkce          = false # TODO: enable
      pkce_challenge_method = ""    # TODO: remove
      redirect_uris = [
        "https://${local.endpoints.open_webui.ingress}/oauth/oidc/callback",
      ]
    }
    kavita = {
      client_name = "Kavita"
      scopes = [
        "openid",
        "email",
        "profile",
        "groups",
        "offline_access",
      ]
      redirect_uris = [
        "https://${local.endpoints.kavita.ingress}/signin-oidc",
      ]
      token_endpoint_auth_method = "client_secret_post"
    }
  }
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
  for_each = local.authelia_oidc_clients

  length  = 32
  special = false
  upper   = false
}

resource "random_password" "authelia-oidc-client-secret" {
  for_each = local.authelia_oidc_clients

  length  = 32
  special = false
}

module "authelia-secret" {
  source  = "../modules/secret"
  name    = "${local.endpoints.authelia.name}-secret-custom"
  app     = local.endpoints.authelia.name
  release = "0.1.0"
  data = merge({
    "litestream" = yamlencode({
      dbs = [
        {
          path                = local.authelia_db_file
          monitor-interval    = "100ms"
          checkpoint-interval = "6s"
          replicas = [
            {
              name          = "minio"
              type          = "s3"
              endpoint      = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
              bucket        = "authelia"
              path          = "$POD_NAME/litestream"
              sync-interval = "100ms"
            },
          ]
        },
      ]
    })
    "oidc-jwk-key"     = tls_private_key.authelia-oidc-jwk.private_key_pem
    "oidc-hmac-secret" = random_password.authelia-oidc-hmac-secret.result
    }, {
    # clients
    for key, client in local.authelia_oidc_clients :
    "oidc-client-id-${key}" => random_string.authelia-oidc-client-id[key].result
    }, {
    for key, client in local.authelia_oidc_clients :
    "oidc-client-secret-${key}" => random_password.authelia-oidc-client-secret[key].result
  })
}

resource "helm_release" "authelia-resources" {
  name             = "${local.endpoints.authelia.name}-resources"
  chart            = "../helm-wrapper"
  namespace        = local.endpoints.authelia.namespace
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      manifests = [
        module.authelia-secret.manifest,

        # lldap client
        yamlencode({
          apiVersion = "cert-manager.io/v1"
          kind       = "Certificate"
          metadata = {
            name = local.authelia_client_tls_secret_name
          }
          spec = {
            secretName = local.authelia_client_tls_secret_name
            isCA       = false
            privateKey = {
              algorithm = "RSA" # TODO: revisit ECDSA
              size      = 4096
            }
            commonName = local.endpoints.authelia.name
            usages = [
              "key encipherment",
              "digital signature",
              "client auth",
            ]
            ipAddresses = [
              "127.0.0.1",
            ]
            dnsNames = [
              local.endpoints.authelia.ingress,
            ]
            issuerRef = {
              name = local.kubernetes.cert_issuers.ca_internal
              kind = "ClusterIssuer"
            }
          }
        }),
      ]
    }),
  ]
}

resource "helm_release" "authelia" {
  name       = local.endpoints.authelia.name
  namespace  = local.endpoints.authelia.namespace
  repository = "https://charts.authelia.com"
  chart      = "authelia"
  version    = "0.10.47"
  values = [
    yamlencode({
      image = {
        registry   = regex(local.container_image_regex, local.container_images.authelia).repository
        repository = regex(local.container_image_regex, local.container_images.authelia).image
        tag        = regex(local.container_image_regex, local.container_images.authelia).tag
      }
      service = {
        type = "ClusterIP"
      }
      ingress = {
        enabled = true
        annotations = {
          "cert-manager.io/cluster-issuer" = local.kubernetes.cert_issuers.acme_prod
        }
        certManager = true
        className   = local.endpoints.ingress_nginx.name
        tls = {
          enabled = true
          secret  = "${local.endpoints.authelia.ingress}-tls"
        }
      }
      pod = {
        replicas = 1
        kind     = "StatefulSet"
        selectors = {
          affinity = {
            podAffinity = {
              requiredDuringSchedulingIgnoredDuringExecution = [
                {
                  labelSelector = {
                    matchExpressions = [
                      {
                        key      = "app"
                        operator = "In"
                        values = [
                          local.endpoints.lldap.name,
                        ]
                      },
                    ]
                  }
                  topologyKey = "kubernetes.io/hostname"
                },
              ]
            }
          }
        }
        extraVolumeMounts = [
          # "authelia" persistent volume is mounted to /config
          {
            name      = "ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            subPath   = "ca.crt"
            readOnly  = true
          },
          {
            name      = "authelia-client-tls"
            mountPath = local.authelia_client_tls_cert_file
            subPath   = "tls.crt"
          },
          {
            name      = "authelia-client-tls"
            mountPath = local.authelia_client_tls_key_file
            subPath   = "tls.key"
          },
          {
            name      = "oidc-client-share"
            mountPath = local.autehlia_oidc_client_shared_path
          },
          {
            name      = "secret-custom"
            mountPath = local.authelia_oidc_hmac_secret_file
            subPath   = "oidc-hmac-secret"
          },
          {
            name      = "secret-custom"
            mountPath = local.authelia_oidc_jwk_key_file
            subPath   = "oidc-jwk-key"
          },
        ]
        extraVolumes = [
          {
            name = "secret-custom"
            secret = {
              secretName = module.authelia-secret.name
            }
          },
          {
            name = "oidc-client-share"
            emptyDir = {
              medium = "Memory"
            }
          },
          {
            name = "ca-trust-bundle"
            configMap = {
              name = local.kubernetes.ca_bundle_configmap
            }
          },
          {
            name = "authelia-client-tls"
            secret = {
              secretName = local.authelia_client_tls_secret_name
            }
          },
        ]
        env = [
          {
            name  = "AUTHELIA_AUTHENTICATION_BACKEND_LDAP_TLS_PRIVATE_KEY_FILE"
            value = local.authelia_client_tls_key_file
          },
          {
            name  = "AUTHELIA_AUTHENTICATION_BACKEND_LDAP_TLS_CERTIFICATE_CHAIN_FILE"
            value = local.authelia_client_tls_cert_file
          },
          {
            name  = "AUTHELIA_IDENTITY_PROVIDERS_OIDC_HMAC_SECRET_FILE"
            value = local.authelia_oidc_hmac_secret_file
          },
        ]
        initContainers = [
          {
            name  = "${local.endpoints.authelia.name}-password-generate"
            image = local.container_images.authelia
            command = [
              "sh",
              "-c",
              <<-EOF
              %{~for key, _ in local.authelia_oidc_clients~}
              authelia crypto hash generate \
                --password "$${OIDC_CLIENT_SECRET_${random_string.authelia-oidc-client-id[key].result}}" pbkdf2 | sed -e 's/Digest: //' > "${local.autehlia_oidc_client_shared_path}/client-secret-${key}"
              %{~endfor~}
              EOF
            ]
            env = [
              for key, _ in local.authelia_oidc_clients :
              {
                name = "OIDC_CLIENT_SECRET_${random_string.authelia-oidc-client-id[key].result}"
                valueFrom = {
                  secretKeyRef = {
                    name = module.authelia-secret.name
                    key  = "oidc-client-secret-${key}"
                  }
                }
              }
            ]
            volumeMounts = [
              {
                name      = "oidc-client-share"
                mountPath = local.autehlia_oidc_client_shared_path
              },
            ]
          },
          {
            name  = "${local.endpoints.authelia.name}-litestream-restore"
            image = local.container_images.litestream
            args = [
              "restore",
              "-if-db-not-exists",
              "-if-replica-exists",
              "-config",
              local.authelia_litestream_config_file,
              local.authelia_db_file,
            ]
            env = [
              {
                name = "POD_NAME"
                valueFrom = {
                  fieldRef = {
                    fieldPath = "metadata.name"
                  }
                }
              },
              {
                name = "AWS_ACCESS_KEY_ID"
                valueFrom = {
                  secretKeyRef = {
                    name = local.minio_users.authelia.secret
                    key  = "AWS_ACCESS_KEY_ID"
                  }
                }
              },
              {
                name = "AWS_SECRET_ACCESS_KEY"
                valueFrom = {
                  secretKeyRef = {
                    name = local.minio_users.authelia.secret
                    key  = "AWS_SECRET_ACCESS_KEY"
                  }
                }
              },
            ]
            volumeMounts = [
              {
                name      = local.endpoints.authelia.name
                mountPath = dirname(local.authelia_db_file)
              },
              {
                name      = "secret-custom"
                mountPath = local.authelia_litestream_config_file
                subPath   = "litestream"
              },
              {
                name      = "ca-trust-bundle"
                mountPath = "/etc/ssl/certs/ca-certificates.crt"
                subPath   = "ca.crt"
                readOnly  = true
              },
            ]
          },
          {
            name          = "${local.endpoints.authelia.name}-litestream-replicate"
            image         = local.container_images.litestream
            restartPolicy = "Always"
            args = [
              "replicate",
              "-config",
              local.authelia_litestream_config_file,
            ]
            env = [
              {
                name = "POD_NAME"
                valueFrom = {
                  fieldRef = {
                    fieldPath = "metadata.name"
                  }
                }
              },
              {
                name = "AWS_ACCESS_KEY_ID"
                valueFrom = {
                  secretKeyRef = {
                    name = local.minio_users.authelia.secret
                    key  = "AWS_ACCESS_KEY_ID"
                  }
                }
              },
              {
                name = "AWS_SECRET_ACCESS_KEY"
                valueFrom = {
                  secretKeyRef = {
                    name = local.minio_users.authelia.secret
                    key  = "AWS_SECRET_ACCESS_KEY"
                  }
                }
              },
            ]
            volumeMounts = [
              {
                name      = local.endpoints.authelia.name
                mountPath = dirname(local.authelia_db_file)
              },
              {
                name      = "secret-custom"
                mountPath = local.authelia_litestream_config_file
                subPath   = "litestream"
              },
              {
                name      = "ca-trust-bundle"
                mountPath = "/etc/ssl/certs/ca-certificates.crt"
                subPath   = "ca.crt"
                readOnly  = true
              },
            ]
          },
        ]
      }
      configMap = {
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
        identity_validation = {
          reset_password = {
            secret = {
              value = random_bytes.authelia-jwt-secret.base64
            }
          }
        }
        authentication_backend = {
          password_reset = {
            disable = true
          }
          # https://github.com/lldap/lldap/blob/main/example_configs/authelia_config.yml
          ldap = {
            enabled        = true
            implementation = "custom"
            tls = {
              skip_verify     = false
              minimum_version = "TLS1.3"
            }
            address = "ldaps://${local.endpoints.lldap.service}:${local.service_ports.ldaps}"
            base_dn = "dc=${join(",dc=", slice(compact(split(".", local.endpoints.lldap.service)), 1, length(compact(split(".", local.endpoints.lldap.service)))))}"
            attributes = {
              username     = "uid"
              mail         = "mail"
              group_name   = "cn"
              display_name = "displayName"
            }
            additional_users_dn  = "ou=people"
            users_filter         = "(&({username_attribute}={input})(objectClass=person))"
            additional_groups_dn = "ou=groups"
            groups_filter        = "(member={dn})"
            user                 = "uid=${random_password.lldap-user.result},ou=people,dc=${join(",dc=", slice(compact(split(".", local.endpoints.lldap.service)), 1, length(compact(split(".", local.endpoints.lldap.service)))))}"
            password = {
              value = random_password.lldap-password.result
            }
          }
          file = {
            enabled = false
          }
        }
        identity_providers = {
          oidc = {
            enabled = true
            hmac_secret = {
              disabled = true
            }
            jwks = [
              {
                use = "sig"
                key = {
                  path = local.authelia_oidc_jwk_key_file
                }
              },
            ]
            enable_client_debug_messages = true
            clients = [
              for key, client in local.authelia_oidc_clients :
              merge({
                client_id = random_string.authelia-oidc-client-id[key].result
                client_secret = {
                  path = "${local.autehlia_oidc_client_shared_path}/client-secret-${key}"
                }
                public                           = false
                authorization_policy             = "two_factor"
                require_pkce                     = true
                pkce_challenge_method            = "S256"
                access_token_signed_response_alg = "none"
                userinfo_signed_response_alg     = "none"
                token_endpoint_auth_method       = "client_secret_basic"
              }, client)
            ]
          }
        }
        session = {
          inactivity  = "4h"
          expiration  = "4h"
          remember_me = 0
          encryption_key = {
            value = random_password.authelia-session-encryption-key.result
          }
          cookies = [
            {
              domain    = regex(local.domain_regex, local.endpoints.authelia.ingress).domain
              subdomain = regex(local.domain_regex, local.endpoints.authelia.ingress).subdomain
            },
          ]
        }
        regulation = {
          max_retries = 4
        }
        storage = {
          encryption_key = {
            value = random_password.authelia-storage-secret.result
          }
          local = {
            enabled = true
            path    = local.authelia_db_file
          }
        }
        notifier = {
          disable_startup_check = true
          smtp = {
            enabled  = true
            address  = "submission://${var.smtp.host}:${var.smtp.port}"
            username = var.smtp.username
            sender   = var.smtp.username
            password = {
              value = var.smtp.password
            }
          }
        }
        access_control = {
          default_policy = "two_factor"
        }
      }
      certificates = {
      }
      secret = {
        additionalSecrets = {
        }
      }
      persistence = { # volume name for mount is "authelia"
        enabled      = true
        storageClass = "local-path"
        accessModes = [
          "ReadWriteOnce",
        ]
      }
    }),
  ]
}