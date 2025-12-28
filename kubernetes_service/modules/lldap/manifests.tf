
resource "random_bytes" "jwt-secret" {
  length = 256
}

resource "random_password" "storage-secret" {
  length  = 128
  special = false
}

locals {
  db_file   = "/data/users.db"
  base_path = "/var/lib/lldap"
  extra_envs = merge(var.extra_configs, {
    LLDAP_LDAP_PORT                = 3890
    LLDAP_HTTP_PORT                = 17170
    LLDAP_LDAPS_OPTIONS__PORT      = var.ports.ldaps
    LLDAP_DATABASE_URL             = "sqlite://${local.db_file}?mode=rwc"
    LLDAP_LDAPS_OPTIONS__CERT_FILE = "${local.base_path}/tls.crt"
    LLDAP_LDAPS_OPTIONS__KEY_FILE  = "${local.base_path}/tls.key"
    LLDAP_KEY_FILE                 = "${local.base_path}/private_key"
    LLDAP_JWT_SECRET               = random_bytes.jwt-secret.base64
    LLDAP_KEY_SEED                 = ""
    LLDAP_HTTP_HOST                = "0.0.0.0"
    LLDAP_LDAP_HOST                = "0.0.0.0"
    LLDAP_HTTP_URL                 = "https://${var.ingress_hostname}"
    LLDAP_LDAP_BASE_DN             = "dc=${join(",dc=", slice(compact(split(".", var.service_hostname)), 1, length(compact(split(".", var.service_hostname)))))}"
  })
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.release
  manifests = merge({
    "templates/statefulset.yaml" = module.statefulset.manifest
    "templates/service.yaml"     = module.service.manifest
    "templates/ingress.yaml"     = module.ingress.manifest
    "templates/secret.yaml"      = module.secret.manifest
    "templates/tls.yaml"         = module.tls.manifest
    }, {
    for i, m in module.litestream-overlay.additional_manifests :
    "templates/litestream-${i}.yaml" => m
  })
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = merge({
    "storage-secret" = random_password.storage-secret.result
    }, {
    for k, v in local.extra_envs :
    tostring(k) => tostring(v)
  })
}

module "service" {
  source  = "../../../modules/service"
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = "ldaps"
        port       = local.extra_envs.LLDAP_LDAPS_OPTIONS__PORT
        protocol   = "TCP"
        targetPort = local.extra_envs.LLDAP_LDAPS_OPTIONS__PORT
      },
      {
        name       = "http"
        port       = local.extra_envs.LLDAP_HTTP_PORT
        protocol   = "TCP"
        targetPort = local.extra_envs.LLDAP_HTTP_PORT
      },
    ]
  }
}

module "ingress" {
  source             = "../../../modules/ingress"
  name               = var.name
  app                = var.name
  release            = var.release
  ingress_class_name = var.ingress_class_name
  annotations        = var.nginx_ingress_annotations
  rules = [
    {
      host = var.ingress_hostname
      paths = [
        {
          service = module.service.name
          port    = local.extra_envs.LLDAP_HTTP_PORT
          path    = "/"
        },
      ]
    },
  ]
}

module "litestream-overlay" {
  source = "../litestream_overlay"

  name    = var.name
  app     = var.name
  release = var.release
  images = {
    litestream = var.images.litestream
  }
  litestream_config = {
    dbs = [
      {
        path                = local.db_file
        monitor-interval    = "100ms"
        checkpoint-interval = "6s"
        replica = {
          type          = "s3"
          endpoint      = var.minio_endpoint
          bucket        = var.minio_bucket
          path          = "$POD_NAME/litestream"
          sync-interval = "100ms"
        }
      },
    ]
  }
  sqlite_path         = local.db_file
  minio_access_secret = var.minio_access_secret

  template_spec = {
    resources = {
      requests = {
        memory = "64Mi"
      }
      limits = {
        memory = "64Mi"
      }
    }
    containers = [
      {
        name  = var.name
        image = var.images.lldap
        args = [
          "run",
          "-c",
          "/dev/null",
        ]
        env = [
          for k, v in local.extra_envs :
          {
            name = tostring(k)
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = tostring(k)
              }
            }
          }
        ]
        volumeMounts = [
          {
            name      = "secret"
            mountPath = local.extra_envs.LLDAP_KEY_FILE
            subPath   = "storage-secret"
          },
          {
            name      = "lldap-cert"
            mountPath = local.extra_envs.LLDAP_LDAPS_OPTIONS__CERT_FILE
            subPath   = "tls.crt"
          },
          {
            name      = "lldap-cert"
            mountPath = local.extra_envs.LLDAP_LDAPS_OPTIONS__KEY_FILE
            subPath   = "tls.key"
          },
        ]
        ports = [
          {
            containerPort = local.extra_envs.LLDAP_HTTP_PORT
          },
          {
            containerPort = local.extra_envs.LLDAP_LDAPS_OPTIONS__PORT
          },
        ]
        readinessProbe = {
          exec = {
            command = [
              "/app/lldap",
              "healthcheck",
              "--config-file",
              "/data/lldap_config.toml",
            ]
          }
        }
        livenessProbe = {
          exec = {
            command = [
              "/app/lldap",
              "healthcheck",
              "--config-file",
              "/data/lldap_config.toml",
            ]
          }
        }
      },
    ]
    volumes = [
      {
        name = "secret"
        secret = {
          secretName = module.secret.name
        }
      },
      {
        name = "lldap-cert"
        secret = {
          secretName = module.tls.name
        }
      },
      {
        name = "${var.name}-litestream-data"
        emptyDir = {
          medium = "Memory"
        }
      },
    ]
  }
}

module "statefulset" {
  source = "../../../modules/statefulset"

  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  annotations = merge({
    "checksum/secret" = sha256(module.secret.manifest)
    "checksum/tls"    = sha256(module.tls.manifest)
    }, {
    for i, m in module.litestream-overlay.additional_manifests :
    "checksum/litestream-${i}" => sha256(m)
  })

  /* persistent path for sqlite
  spec = {
    volumeClaimTemplates = [
      {
        metadata = {
          name = "${var.name}-litestream-data"
        }
        spec = {
          accessModes = [
            "ReadWriteOnce",
          ]
          resources = {
            requests = {
              storage = "16Gi"
            }
          }
          storageClassName = "local-path"
        }
      },
    ]
  }
  */
  template_spec = module.litestream-overlay.template_spec
}