locals {
  name      = split(".", var.cluster_service_endpoint)[0]
  namespace = split(".", var.cluster_service_endpoint)[1]
  ports = merge(var.ports, {
    lldap      = 3890
    lldap_http = 17170
  })

  db_path             = "/data/users.db"
  base_path           = "/var/lib/lldap"
  storage_secret_path = "${local.base_path}/private_key"
  ldaps_cert_path     = "${local.base_path}/cert.pem"
  ldaps_key_path      = "${local.base_path}/key.pem"
  extra_envs = merge(var.extra_configs, {
    LLDAP_LDAP_PORT           = local.ports.lldap
    LLDAP_HTTP_PORT           = local.ports.lldap_http
    LLDAP_LDAPS_OPTIONS__PORT = local.ports.lldap_ldaps

    LLDAP_DATABASE_URL             = "sqlite://${local.db_path}?mode=rwc"
    LLDAP_LDAPS_OPTIONS__CERT_FILE = local.ldaps_cert_path
    LLDAP_LDAPS_OPTIONS__KEY_FILE  = local.ldaps_key_path
    LLDAP_KEY_FILE                 = local.storage_secret_path
    LLDAP_KEY_SEED                 = ""

    LLDAP_HTTP_HOST    = "0.0.0.0"
    LLDAP_LDAP_HOST    = "0.0.0.0"
    LLDAP_HTTP_URL     = "https://${var.service_hostname}"
    LLDAP_LDAP_BASE_DN = "dc=${join(",dc=", slice(compact(split(".", var.service_hostname)), 1, length(compact(split(".", var.service_hostname)))))}"
  })
}

module "metadata" {
  source      = "../metadata"
  name        = local.name
  namespace   = local.namespace
  release     = var.release
  app_version = split(":", var.images.lldap)[1]
  manifests = merge(module.litestream.chart.manifests, {
    "templates/service.yaml" = module.service.manifest
    "templates/ingress.yaml" = module.ingress.manifest
    "templates/secret.yaml"  = module.secret.manifest
  })
}

module "secret" {
  source  = "../secret"
  name    = local.name
  app     = local.name
  release = var.release
  data = merge({
    basename(local.storage_secret_path) = var.storage_secret
    basename(local.ldaps_cert_path)     = tls_locally_signed_cert.lldap.cert_pem
    basename(local.ldaps_key_path)      = tls_private_key.lldap.private_key_pem
    }, {
    for k, v in local.extra_envs :
    tostring(k) => tostring(v)
  })
}

module "service" {
  source  = "../service"
  name    = local.name
  app     = local.name
  release = var.release
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = "ldaps"
        port       = local.ports.lldap_ldaps
        protocol   = "TCP"
        targetPort = local.ports.lldap_ldaps
      },
      {
        name       = "http"
        port       = local.ports.lldap_http
        protocol   = "TCP"
        targetPort = local.ports.lldap_http
      },
    ]
  }
}

module "ingress" {
  source             = "../ingress"
  name               = local.name
  app                = local.name
  release            = var.release
  ingress_class_name = var.ingress_class_name
  annotations        = var.nginx_ingress_annotations
  rules = [
    {
      host = var.service_hostname
      paths = [
        {
          service = module.service.name
          port    = local.ports.lldap_http
          path    = "/"
        },
      ]
    },
  ]
}

module "litestream" {
  source = "../statefulset_litestream"
  ## litestream settings
  images = {
    litestream = var.images.litestream
  }
  litestream_config = {
    dbs = [
      {
        path = local.db_path
        replicas = [
          {
            name                     = "minio"
            type                     = "s3"
            bucket                   = var.litestream_minio_bucket
            path                     = local.name
            endpoint                 = "http://${var.litestream_minio_endpoint}"
            access-key-id            = var.litestream_minio_access_key_id
            secret-access-key        = var.litestream_minio_secret_access_key
            retention                = "2m"
            retention-check-interval = "2m"
            sync-interval            = "100ms"
            snapshot-interval        = "20m"
          },
          {
            name              = "s3"
            url               = "s3://${var.litestream_s3_resource}/${basename(local.db_path)}"
            access-key-id     = var.litestream_s3_access_key_id
            secret-access-key = var.litestream_s3_secret_access_key
          },
        ]
      },
    ]
  }
  sqlite_path = local.db_path
  ##
  name     = local.name
  app      = local.name
  release  = var.release
  affinity = var.affinity
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  template_spec = {
    containers = [
      {
        name  = local.name
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
            mountPath = local.storage_secret_path
            subPath   = basename(local.storage_secret_path)
          },
          {
            name      = "secret"
            mountPath = local.ldaps_cert_path
            subPath   = basename(local.ldaps_cert_path)
          },
          {
            name      = "secret"
            mountPath = local.ldaps_key_path
            subPath   = basename(local.ldaps_key_path)
          },
        ]
        ports = [
          {
            containerPort = local.ports.lldap_http
          },
          {
            containerPort = local.ports.lldap_ldaps
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
        name = "litestream-data"
        emptyDir = {
          medium = "Memory"
        }
      },
    ]
  }
}
