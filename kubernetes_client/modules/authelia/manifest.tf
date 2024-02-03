module "secret-custom" {
  source  = "../secret"
  name    = "${var.name}-custom"
  app     = var.name
  release = var.release
  data = {
    ACCESS_KEY_ID     = var.s3_access_key_id
    SECRET_ACCESS_KEY = var.s3_secret_access_key
    "users_database.yaml" = yamlencode({
      users = {
        for email, user in var.users :
        email => merge({
          email       = email
          displayname = email
        }, user)
      }
    })
  }
}

data "helm_template" "authelia" {
  name       = var.name
  namespace  = var.namespace
  repository = "https://charts.authelia.com"
  chart      = "authelia"
  version    = var.source_release
  values = [
    yamlencode({
      domain = local.domain
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
        subdomain   = compact(split(".", var.service_hostname))[0]
        tls = {
          enabled = true
          secret  = "${local.domain}-tls"
        }
      }
      pod = {
        replicas = 1
        kind     = "StatefulSet"
        annotations = {
          "checksum/custom" = sha256(module.secret-custom.manifest)
        }
        extraVolumeMounts = [
          {
            name      = "authelia-data"
            mountPath = "/config"
          },
          {
            name      = "authelia-custom"
            mountPath = "/config/users_database.yaml"
            subPath   = "users_database.yaml"
          },
        ]
        extraVolumes = [
          {
            name = "authelia-data"
            emptyDir = {
              medium = "Memory"
            }
          },
          {
            name = "authelia-custom"
            secret = {
              secretName = "${var.name}-custom"
            }
          },
        ]
      }
      configMap = {
        telemetry = {
          metrics = {
            enabled = false
          }
        }
        default_redirection_url = "https://${var.service_hostname}"
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
            disable = true
          }
          ldap = {
            enabled = false
          }
          file = {
            enabled = true
            path    = "/config/users_database.yaml"
          }
        }
        session = {
          inactivity           = "4h"
          expiration           = "4h"
          remember_me_duration = 0
          redis = {
            enabled = false
          }
        }
        regulation = {
          max_retries = 4
        }
        storage = {
          local = {
            enabled = true
          }
          mysql = {
            enabled = false
          }
          postgres = {
            enabled = false
          }
        }
        notifier = {
          disable_startup_check = true
          smtp = {
            enabled       = true
            enabledSecret = true
            host          = var.smtp_host
            port          = var.smtp_port
            username      = var.smtp_username
            sender        = var.smtp_username
          }
        }
        access_control = merge({
          default_policy = "two_factor"
        }, var.access_control)
      }
      secret = {
        jwt = {
          value = var.jwt_token
        }
        storageEncryptionKey = {
          value = var.storage_secret
        }
        session = {
          value = var.session_encryption_key
        }
        smtp = {
          value = var.smtp_password
        }
      }
      persistence = {
        enabled = false
      }
    }),
  ]
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.source_release
  manifests   = local.manifests
}

locals {
  domain  = join(".", slice(compact(split(".", var.service_hostname)), 1, length(compact(split(".", var.service_hostname)))))
  db_path = "/config/db.sqlite3"

  s = yamldecode(data.helm_template.authelia.manifests["templates/deployment.yaml"])
  manifests = merge(data.helm_template.authelia.manifests, {
    "templates/secret-custom.yaml" = module.secret-custom.manifest
    "templates/deployment.yaml" = yamlencode(merge(local.s, {
      spec = merge(local.s.spec, {
        template = merge(local.s.spec.template, {
          spec = merge(local.s.spec.template.spec, {
            strategy = {
              type = "Recreate"
            }
            initContainers = [
              {
                name  = "${var.name}-init"
                image = var.images.litestream
                args = [
                  "restore",
                  "-if-replica-exists",
                  "-o",
                  local.db_path,
                  "s3://${var.s3_db_resource}",
                ]
                env = [
                  {
                    name = "LITESTREAM_ACCESS_KEY_ID"
                    valueFrom = {
                      secretKeyRef = {
                        name = "${var.name}-custom"
                        key  = "ACCESS_KEY_ID"
                      }
                    }
                  },
                  {
                    name = "LITESTREAM_SECRET_ACCESS_KEY"
                    valueFrom = {
                      secretKeyRef = {
                        name = "${var.name}-custom"
                        key  = "SECRET_ACCESS_KEY"
                      }
                    }
                  },
                ]
                volumeMounts = [
                  {
                    name      = "authelia-data"
                    mountPath = "/config"
                  },
                ]
              }
            ]
            containers = concat(local.s.spec.template.spec.containers, [
              {
                name  = "${var.name}-backup"
                image = var.images.litestream
                args = [
                  "replicate",
                  local.db_path,
                  "s3://${var.s3_db_resource}",
                ]
                env = [
                  {
                    name = "LITESTREAM_ACCESS_KEY_ID"
                    valueFrom = {
                      secretKeyRef = {
                        name = "${var.name}-custom"
                        key  = "ACCESS_KEY_ID"
                      }
                    }
                  },
                  {
                    name = "LITESTREAM_SECRET_ACCESS_KEY"
                    valueFrom = {
                      secretKeyRef = {
                        name = "${var.name}-custom"
                        key  = "SECRET_ACCESS_KEY"
                      }
                    }
                  },
                ]
                volumeMounts = [
                  {
                    name      = "authelia-data"
                    mountPath = "/config"
                  },
                ]
              },
            ])
            dnsConfig = {
              options = [
                {
                  name  = "ndots"
                  value = "2"
                },
              ]
            }
          })
        })
      })
    }))
  })
}