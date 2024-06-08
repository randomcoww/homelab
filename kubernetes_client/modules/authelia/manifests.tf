module "secret-custom" {
  source  = "../secret"
  name    = "${var.name}-custom"
  app     = var.name
  release = var.source_release
  data = {
    ACCESS_KEY_ID                      = var.s3_access_key_id
    SECRET_ACCESS_KEY                  = var.s3_secret_access_key
    LDAP_CLIENT_TLS_CERTIFICATE_CHAIN  = chomp(tls_locally_signed_cert.lldap.cert_pem)
    LDAP_CLIENT_TLS_PRIVATE_KEY        = chomp(tls_private_key.lldap.private_key_pem)
    REDIS_CLIENT_TLS_CERTIFICATE_CHAIN = chomp(tls_locally_signed_cert.redis.cert_pem)
    REDIS_CLIENT_TLS_PRIVATE_KEY       = chomp(tls_private_key.redis.private_key_pem)
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
            mountPath = local.ldap_client_key_path
            subPath   = "LDAP_CLIENT_TLS_PRIVATE_KEY"
          },
          {
            name      = "authelia-custom"
            mountPath = local.ldap_client_cert_path
            subPath   = "LDAP_CLIENT_TLS_CERTIFICATE_CHAIN"
          },
          {
            name      = "authelia-custom"
            mountPath = local.redis_client_key_path
            subPath   = "REDIS_CLIENT_TLS_PRIVATE_KEY"
          },
          {
            name      = "authelia-custom"
            mountPath = local.redis_client_cert_path
            subPath   = "REDIS_CLIENT_TLS_CERTIFICATE_CHAIN"
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
              secretName = module.secret-custom.name
            }
          },
        ]
        env = [
          {
            name  = "AUTHELIA_AUTHENTICATION_BACKEND_LDAP_TLS_PRIVATE_KEY_FILE"
            value = local.ldap_client_key_path
          },
          {
            name  = "AUTHELIA_AUTHENTICATION_BACKEND_LDAP_TLS_CERTIFICATE_CHAIN_FILE"
            value = local.ldap_client_cert_path
          },
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
      configMap = merge(var.configmap, {
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
      })
      secret = var.secret
      certificates = {
        values = [
          {
            name  = "lldap-ca.pem"
            value = var.lldap_ca.cert_pem
          },
          {
            name  = "redis-ca.pem"
            value = var.redis_ca.cert_pem
          }
        ]
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
  release     = var.source_release
  app_version = var.source_release
  manifests   = local.manifests
}

locals {
  domain                 = join(".", slice(compact(split(".", var.service_hostname)), 1, length(compact(split(".", var.service_hostname)))))
  db_path                = "/config/db.sqlite3"
  ldap_client_cert_path  = "/custom/ldap-client-cert.pem"
  ldap_client_key_path   = "/custom/ldap-client-key.pem"
  redis_client_cert_path = "/custom/redis-client-cert.pem"
  redis_client_key_path  = "/custom/redis-client-key.pem"

  s = yamldecode(data.helm_template.authelia.manifests["templates/deployment.yaml"])
  manifests = merge(data.helm_template.authelia.manifests, {
    "templates/secret-custom.yaml" = module.secret-custom.manifest
    "templates/deployment.yaml" = yamlencode(merge(local.s, {
      spec = merge(local.s.spec, {
        template = merge(local.s.spec.template, {
          spec = merge(local.s.spec.template.spec, {
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
                        name = module.secret-custom.name
                        key  = "ACCESS_KEY_ID"
                      }
                    }
                  },
                  {
                    name = "LITESTREAM_SECRET_ACCESS_KEY"
                    valueFrom = {
                      secretKeyRef = {
                        name = module.secret-custom.name
                        key  = "SECRET_ACCESS_KEY"
                      }
                    }
                  },
                ]
                volumeMounts = [
                  {
                    name      = "authelia-data"
                    mountPath = dirname(local.db_path)
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
                        name = module.secret-custom.name
                        key  = "ACCESS_KEY_ID"
                      }
                    }
                  },
                  {
                    name = "LITESTREAM_SECRET_ACCESS_KEY"
                    valueFrom = {
                      secretKeyRef = {
                        name = module.secret-custom.name
                        key  = "SECRET_ACCESS_KEY"
                      }
                    }
                  },
                ]
                volumeMounts = [
                  {
                    name      = "authelia-data"
                    mountPath = dirname(local.db_path)
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