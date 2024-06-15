locals {
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
    path              = "/var/lib/clickhouse/mnt"
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
      storage_policy = "s3"
    }
    storage_configuration = {
      "@replace" = "replace"
      disks = [
        {
          s3 = {
            type                 = "object_storage"
            object_storage_type  = "s3"
            metadata_type        = "plain_rewritable"
            endpoint             = "http://${var.data_minio_endpoint}/${var.data_minio_bucket}/${var.name}/"
            access_key_id        = var.data_minio_access_key_id
            secret_access_key    = var.data_minio_secret_access_key
            support_batch_delete = true
          }
        },
      ]
      policies = {
        s3 = {
          volumes = {
            main = {
              disks = "s3"
            }
          }
        }
      }
    }
  })
  jfs_metadata_path = "/var/lib/jfs/${var.name}.db"
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.clickhouse)[1]
  manifests = {
    "templates/service.yaml"           = module.service.manifest
    "templates/secret.yaml"            = module.secret.manifest
    "templates/statefulset.yaml"       = module.statefulset-jfs.statefulset
    "templates/secret-litestream.yaml" = module.statefulset-jfs.secret
  }
}

module "secret" {
  source  = "../secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    basename(local.config_path)  = yamlencode(local.clickhouse_config)
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

module "statefulset-jfs" {
  source = "../statefulset_jfs"
  ## litestream settings
  litestream_image = var.images.litestream
  litestream_config = {
    dbs = [
      {
        path = local.jfs_metadata_path
        replicas = [
          {
            type                     = "s3"
            bucket                   = var.jfs_minio_bucket
            path                     = basename(local.jfs_metadata_path)
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
  }
  sqlite_path = local.jfs_metadata_path

  ## jfs settings
  jfs_image                   = var.images.juicefs
  jfs_mount_path              = local.clickhouse_config.path
  jfs_minio_resource          = "http://${var.jfs_minio_endpoint}/${var.jfs_minio_bucket}"
  jfs_minio_access_key_id     = var.jfs_minio_access_key_id
  jfs_minio_secret_access_key = var.jfs_minio_secret_access_key
  ##

  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  spec = {
    containers = [
      {
        name  = var.name
        image = var.images.clickhouse
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          mountpoint ${local.clickhouse_config.path}

          rm -f ${local.clickhouse_config.path}/status
          exec clickhouse-server \
            -C /etc/clickhouse-server/config.xml
          EOF
        ]
        volumeMounts = [
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
    ]
  }
}