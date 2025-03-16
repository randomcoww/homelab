module "secret" {
  source  = "../../../modules/secret"
  name    = "${var.name}-custom"
  app     = var.name
  release = var.helm_template.version
  data = {
    basename(local.ldap_client_cert_path)  = tls_locally_signed_cert.lldap-client.cert_pem
    basename(local.ldap_client_key_path)   = tls_private_key.lldap-client.private_key_pem
    basename(local.redis_client_cert_path) = tls_locally_signed_cert.redis-client.cert_pem
    basename(local.redis_client_key_path)  = tls_private_key.redis-client.private_key_pem
  }
}

module "secret-litestream" {
  source  = "../../../modules/secret"
  name    = "${var.name}-litestream"
  app     = var.name
  release = var.helm_template.version
  data = {
    basename(local.litestream_config_path) = yamlencode({
      dbs = [
        {
          path = local.sqlite_path
          replicas = [
            {
              name              = "minio"
              type              = "s3"
              endpoint          = var.minio_endpoint
              bucket            = var.minio_bucket
              path              = var.minio_litestream_prefix
              access-key-id     = var.minio_access_key_id
              secret-access-key = var.minio_secret_access_key
              sync-interval     = "100ms"
              snapshot-interval = "8m"
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
            name     = "authelia-data"
            emptyDir = {}
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
        session = merge(var.configmap.session, {
          cookies = concat(lookup(var.configmap.session, "cookies", []), [
            {
              domain    = local.domain
              subdomain = local.subdomain
            },
          ])
          redis = {
            enabled = true
            deploy  = false
            host    = "${var.name}-redis.${var.namespace}"
            port    = local.redis_port
            password = {
              disabled = true
            }
            tls = {
              enabled         = true
              skip_verify     = false
              minimum_version = "TLS1.3"
            }
          }
        })
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
            value = tls_self_signed_cert.redis-ca.cert_pem
          },
        ]
      }
      persistence = {
        enabled = false
      }
    }),
  ]
}

module "redis" {
  source    = "../keydb"
  name      = "${var.name}-redis"
  namespace = var.namespace
  release   = var.helm_template.version
  replicas  = var.redis_replicas
  images = {
    keydb = var.images.keydb
  }
  ports = {
    keydb = local.redis_port
  }
  ca = {
    algorithm       = tls_private_key.redis-ca.algorithm
    private_key_pem = tls_private_key.redis-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.redis-ca.cert_pem
  }
}

module "metadata" {
  source    = "../../../modules/metadata"
  name      = var.name
  namespace = var.namespace
  release   = var.helm_template.version
  manifests = merge(local.manifests, module.redis.chart.manifests)
}

locals {
  domain                 = join(".", slice(compact(split(".", var.service_hostname)), 1, length(compact(split(".", var.service_hostname)))))
  subdomain              = compact(split(".", var.service_hostname))[0]
  litestream_config_path = "/etc/litestream.yml"
  sqlite_path            = var.configmap.storage.local.path
  ldap_client_cert_path  = "/custom/ldap-client-cert.pem"
  ldap_client_key_path   = "/custom/ldap-client-key.pem"
  redis_client_cert_path = "/custom/redis-client-cert.pem"
  redis_client_key_path  = "/custom/redis-client-key.pem"
  redis_port             = 6379

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
                env = [
                  {
                    name = "POD_NAME"
                    valueFrom = {
                      fieldRef = {
                        fieldPath = "metadata.name"
                      }
                    }
                  },
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
              {
                name          = "${var.name}-litestream-replicate"
                image         = var.images.litestream
                restartPolicy = "Always"
                args = [
                  "replicate",
                  "-config",
                  local.litestream_config_path,
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
            ]
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