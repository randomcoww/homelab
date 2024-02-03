module "secret-custom" {
  source  = "../secret"
  name    = "${var.name}-custom"
  app     = var.name
  release = var.release
  data = {
    ACCESS_KEY_ID     = var.s3_access_key_id
    SECRET_ACCESS_KEY = var.s3_secret_access_key
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