locals {
  jfs_db_path  = "/var/lib/jfs/${var.name}.db"
  base_path    = "/etc/clickhouse-server"
  config_path  = "${local.base_path}/config.d/server.yaml"
  cert_path    = "${local.base_path}/server.crt"
  key_path     = "${local.base_path}/server.key"
  ca_cert_path = "${local.base_path}/ca.crt"

  clickhouse_config = merge({
    mysql_port        = 9004
    postgresql_port   = 9005
    https_port        = 8443
    tcp_port_secure   = 9440
    path              = "/var/lib/clickhouse"
    tmp_path          = "/var/tmp/clickhouse"
    listen_reuse_port = 1
    }, var.clickhouse_config, {
    logger = {
      "@replace" = "replace"
      level      = "debug"
      console    = 1
    }
    grpc = {
      enable_ssl       = true
      ssl_cert_file    = local.cert_path
      ssl_key_file     = local.key_path
      ssl_ca_cert_file = local.ca_cert_path
    }
    openSSL = {
      server = {
        certificateFile = local.cert_path
        privateKeyFile  = local.key_path
        caConfig        = local.ca_cert_path
      }
    }
    merge_tree = {
      storage_policy = "all"
    }
    storage_configuration = {
      "@replace" = "replace"
      disks = {
        s3 = {
          type                    = "object_storage"
          object_storage_type     = "s3"
          metadata_type           = "plain_rewritable"
          endpoint                = "http://${var.data_minio_endpoint}/${var.data_minio_bucket}/${var.name}/db/"
          access_key_id           = var.data_minio_access_key_id
          secret_access_key       = var.data_minio_secret_access_key
          cache_enabled           = true
          data_cache_enabled      = true
          enable_filesystem_cache = true
        }
      }
      policies = {
        all = {
          volumes = {
            main = {
              disks = "s3"
            }
          }
        }
      }
    }
  })
  litestream_config_path = "/etc/litestream.yml"
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.clickhouse)[1]
  manifests = {
    "templates/service.yaml"     = module.service.manifest
    "templates/secret.yaml"      = module.secret.manifest
    "templates/statefulset.yaml" = module.statefulset.manifest
  }
}

module "secret" {
  source  = "../secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    basename(local.config_path) = yamlencode(local.clickhouse_config)
    basename(local.litestream_config_path) = yamlencode({
      dbs = [
        {
          path = local.jfs_db_path
          replicas = [
            {
              type                     = "s3"
              bucket                   = var.jfs_minio_bucket
              path                     = basename(local.jfs_db_path)
              endpoint                 = "http://${var.jfs_minio_endpoint}"
              access-key-id            = var.jfs_minio_access_key_id
              secret-access-key        = var.jfs_minio_secret_access_key
              retention                = "2m"
              retention-check-interval = "2m"
              sync-interval            = "500ms"
              snapshot-interval        = "1h"
            },
          ]
        },
      ]
    })
    basename(local.cert_path)    = chomp(tls_locally_signed_cert.clickhouse.cert_pem)
    basename(local.key_path)     = chomp(tls_private_key.clickhouse.private_key_pem)
    basename(local.ca_cert_path) = chomp(var.ca.cert_pem)
  }
}

module "service" {
  source  = "../service"
  name    = var.name
  app     = var.name
  release = var.release
  annotations = {
    "external-dns.alpha.kubernetes.io/hostname" = var.service_hostname
  }
  spec = {
    type = "LoadBalancer"
    externalIPs = [
      var.service_ip,
    ]
    ports = [
      {
        name       = "mysql"
        port       = local.clickhouse_config.mysql_port
        protocol   = "TCP"
        targetPort = local.clickhouse_config.mysql_port
      },
      {
        name       = "postgresql"
        port       = local.clickhouse_config.postgresql_port
        protocol   = "TCP"
        targetPort = local.clickhouse_config.postgresql_port
      },
      {
        name       = "https"
        port       = local.clickhouse_config.https_port
        protocol   = "TCP"
        targetPort = local.clickhouse_config.https_port
      },
      {
        name       = "tcp"
        port       = local.clickhouse_config.tcp_port_secure
        protocol   = "TCP"
        targetPort = local.clickhouse_config.tcp_port_secure
      },
    ]
  }
}

module "statefulset" {
  source   = "../statefulset"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = 1
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  spec = {
    initContainers = [
      {
        name  = "${var.name}-init"
        image = var.images.litestream
        args = [
          "restore",
          "-if-replica-exists",
          "-config",
          local.litestream_config_path,
          local.jfs_db_path,
        ]
        volumeMounts = [
          {
            name      = "jfs-data"
            mountPath = dirname(local.jfs_db_path)
          },
          {
            name      = "secret"
            mountPath = local.litestream_config_path
            subPath   = basename(local.litestream_config_path)
          },
        ]
      },
    ]
    containers = [
      {
        name  = var.name
        image = var.images.clickhouse
        env = [
          {
            name  = "CLICKHOUSE_DATA_PATH"
            value = local.clickhouse_config.path
          },
          {
            name  = "JFS_RESOURCE_NAME"
            value = var.name
          },
          {
            name  = "JFS_MINIO_BUCKET"
            value = "http://${var.jfs_minio_endpoint}/${var.jfs_minio_bucket}"
          },
          {
            name  = "JFS_DB_PATH"
            value = local.jfs_db_path
          },
          {
            name  = "JFS_MINIO_ACCESS_KEY_ID"
            value = var.jfs_minio_access_key_id
          },
          {
            name  = "JFS_MINIO_SECRET_ACCESS_KEY"
            value = var.jfs_minio_secret_access_key
          },
        ]
        volumeMounts = [
          {
            name      = "jfs-data"
            mountPath = dirname(local.jfs_db_path)
          },
          {
            name      = "secret"
            mountPath = local.config_path
            subPath   = basename(local.config_path)
          },
          {
            name      = "secret"
            mountPath = local.cert_path
            subPath   = basename(local.cert_path)
          },
          {
            name      = "secret"
            mountPath = local.key_path
            subPath   = basename(local.key_path)
          },
          {
            name      = "secret"
            mountPath = local.ca_cert_path
            subPath   = basename(local.ca_cert_path)
          },
        ]
        ports = [
          {
            name          = "mysql"
            containerPort = local.clickhouse_config.mysql_port
          },
          {
            name          = "postgresql"
            containerPort = local.clickhouse_config.postgresql_port
          },
          {
            name          = "https"
            containerPort = local.clickhouse_config.https_port
          },
          {
            name          = "tcp"
            containerPort = local.clickhouse_config.tcp_port_secure
          },
        ]
        resources = merge({
          limits = {
            "github.com/fuse" = 1
          }
        }, var.resources)
        securityContext = {
          capabilities = {
            add = [
              "SYS_ADMIN",
            ]
          }
        }
      },
      {
        name  = "${var.name}-backup"
        image = var.images.litestream
        args = [
          "replicate",
          "-config",
          local.litestream_config_path,
        ]
        volumeMounts = [
          {
            name      = "jfs-data"
            mountPath = dirname(local.jfs_db_path)
          },
          {
            name      = "secret"
            mountPath = local.litestream_config_path
            subPath   = basename(local.litestream_config_path)
          },
        ]
      },
    ]
    volumes = [
      {
        name = "secret"
        secret = {
          secretName  = module.secret.name
          defaultMode = 493
        }
      },
      {
        name = "jfs-data"
        emptyDir = {
          medium = "Memory"
        }
      },
    ]
  }
}