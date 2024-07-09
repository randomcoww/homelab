module "secret" {
  source  = "../secret"
  name    = "${var.name}-custom"
  app     = var.name
  release = var.source_release
  data = {
    basename(local.ldap_client_cert_path)  = tls_locally_signed_cert.lldap.cert_pem
    basename(local.ldap_client_key_path)   = tls_private_key.lldap.private_key_pem
    basename(local.redis_client_cert_path) = tls_locally_signed_cert.redis.cert_pem
    basename(local.redis_client_key_path)  = tls_private_key.redis.private_key_pem
  }
}

module "secret-litestream" {
  source  = "../secret"
  name    = "${var.name}-litestream"
  app     = var.name
  release = var.source_release
  data = {
    basename(local.litestream_config_path) = yamlencode({
      dbs = [
        {
          path = local.sqlite_path
          replicas = [
            {
              name                     = "minio"
              type                     = "s3"
              bucket                   = var.litestream_minio_bucket
              path                     = var.name
              endpoint                 = "http://${var.litestream_minio_endpoint}"
              access-key-id            = var.litestream_minio_access_key_id
              secret-access-key        = var.litestream_minio_secret_access_key
              retention                = "2m"
              retention-check-interval = "2m"
              sync-interval            = "500ms"
              snapshot-interval        = "1h"
            },
            {
              name              = "s3"
              url               = "s3://${var.litestream_s3_resource}/${basename(local.sqlite_path)}"
              access-key-id     = var.litestream_s3_access_key_id
              secret-access-key = var.litestream_s3_secret_access_key
            },
          ]
        },
      ]
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
          "checksum/secret-custom"     = sha256(module.secret.manifest)
          "checksum/secret-litestream" = sha256(module.secret-litestream.manifest)
        }
        extraVolumeMounts = [
          {
            name      = "authelia-data"
            mountPath = dirname(local.sqlite_path)
          },
          {
            name      = "secret-custom"
            mountPath = local.ldap_client_key_path
            subPath   = basename(local.ldap_client_key_path)
          },
          {
            name      = "secret-custom"
            mountPath = local.ldap_client_cert_path
            subPath   = basename(local.ldap_client_cert_path)
          },
          {
            name      = "secret-custom"
            mountPath = local.redis_client_key_path
            subPath   = basename(local.redis_client_key_path)
          },
          {
            name      = "secret-custom"
            mountPath = local.redis_client_cert_path
            subPath   = basename(local.redis_client_cert_path)
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
            name = "secret-custom"
            secret = {
              secretName = module.secret.name
            }
          },
          {
            name = "litestream-config"
            secret = {
              secretName = module.secret-litestream.name
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
          },
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
  litestream_config_path = "/etc/litestream.yml"
  sqlite_path            = "/config/db.sqlite3"
  ldap_client_cert_path  = "/custom/ldap-client-cert.pem"
  ldap_client_key_path   = "/custom/ldap-client-key.pem"
  redis_client_cert_path = "/custom/redis-client-cert.pem"
  redis_client_key_path  = "/custom/redis-client-key.pem"

  s = yamldecode(data.helm_template.authelia.manifests["templates/deployment.yaml"])
  manifests = merge(data.helm_template.authelia.manifests, {
    "templates/secret-custom.yaml"     = module.secret.manifest
    "templates/secret-litestream.yaml" = module.secret-litestream.manifest
    "templates/deployment.yaml" = yamlencode(merge(local.s, {
      spec = merge(local.s.spec, {
        template = merge(local.s.spec.template, {
          spec = merge(local.s.spec.template.spec, {
            initContainers = [
              {
                name  = "${var.name}-litestream-restore"
                image = var.images.litestream
                args = [
                  "restore",
                  "-if-db-not-exists",
                  "-if-replica-exists",
                  "-config",
                  local.litestream_config_path,
                  local.sqlite_path,
                ]
                volumeMounts = [
                  {
                    name      = "authelia-data"
                    mountPath = dirname(local.sqlite_path)
                  },
                  {
                    name      = "litestream-config"
                    mountPath = local.litestream_config_path
                    subPath   = basename(local.litestream_config_path)
                  },
                ]
              }
            ]
            containers = concat(local.s.spec.template.spec.containers, [
              {
                name  = "${var.name}-litestream-replicate"
                image = var.images.litestream
                args = [
                  "replicate",
                  "-config",
                  local.litestream_config_path,
                ]
                volumeMounts = [
                  {
                    name      = "authelia-data"
                    mountPath = dirname(local.sqlite_path)
                  },
                  {
                    name      = "litestream-config"
                    mountPath = local.litestream_config_path
                    subPath   = basename(local.litestream_config_path)
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