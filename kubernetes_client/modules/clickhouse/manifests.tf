locals {
  name                  = split(".", var.cluster_service_endpoint)[0]
  namespace             = split(".", var.cluster_service_endpoint)[1]
  peer_name             = "${local.name}-peer"
  peer_service_endpoint = "${local.peer_name}.${join(".", slice(split(".", var.cluster_service_endpoint), 1, length(split(".", var.cluster_service_endpoint))))}"

  members = [
    for i in range(var.replicas) :
    "${local.name}-${i}"
  ]

  base_path    = "/etc/clickhouse-server"
  config_path  = "${local.base_path}/config.d/server.yaml"
  cert_path    = "${local.base_path}/server.crt"
  key_path     = "${local.base_path}/server.key"
  ca_cert_path = "${local.base_path}/ca.crt"
  ports = {
    clickhouse = 9440
    keeper     = 9281
    raft       = 9444
  }

  clickhouse_config = merge({
    mysql_port             = 9004
    postgresql_port        = 9005
    http_port              = 8123
    https_port             = 8443
    interserver_https_port = 9010
    interserver_http_port = {
      "@remove" = "remove"
    }
    tcp_port_secure   = local.ports.clickhouse
    path              = "/var/lib/clickhouse/mnt"
    listen_reuse_port = 1
    }, var.extra_clickhouse_config, {
    logger = {
      "@replace" = "replace"
      level      = "warning"
      console    = 1
    }
    grpc = {
      enable_ssl       = 1
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
      client = {
        caConfig = local.ca_cert_path
      }
    }
    storage_configuration = {
      "@replace" = "replace"
      disks = {
        s3 = {
          type                 = "object_storage"
          object_storage_type  = "s3"
          metadata_type        = "plain_rewritable"
          endpoint             = "http://${var.data_minio_endpoint}/${var.data_minio_bucket}/${local.name}/s3/"
          access_key_id        = var.data_minio_access_key_id
          secret_access_key    = var.data_minio_secret_access_key
          region               = ""
          support_batch_delete = true
        }
        # needs old formatting for keeper storage configs
        log_s3_plain = {
          type              = "s3_plain"
          endpoint          = "http://${var.data_minio_endpoint}/${var.data_minio_bucket}/${local.name}/log/"
          access_key_id     = var.data_minio_access_key_id
          secret_access_key = var.data_minio_secret_access_key
          region            = ""
        }
        snapshot_s3_plain = {
          type              = "s3_plain"
          endpoint          = "http://${var.data_minio_endpoint}/${var.data_minio_bucket}/${local.name}/snapshot/"
          access_key_id     = var.data_minio_access_key_id
          secret_access_key = var.data_minio_secret_access_key
          region            = ""
        }
        state_s3_plain = {
          type              = "s3_plain"
          endpoint          = "http://${var.data_minio_endpoint}/${var.data_minio_bucket}/${local.name}/state/"
          access_key_id     = var.data_minio_access_key_id
          secret_access_key = var.data_minio_secret_access_key
          region            = ""
        }
      }
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
    merge_tree = {
      storage_policy                        = "s3"
      allow_remote_fs_zero_copy_replication = false
    }
    asynchronous_metric_log = {
      "@remove" = "remove"
    }
    metric_log = {
      "@remove" = "remove"
    }
    opentelemetry_span_log = {
      "@remove" = "remove"
    }
    zookeeper_log = {
      "@remove" = "remove"
    }
    text_log = {
      "@remove" = "remove"
    }
    session_log = {
      "@remove" = "remove"
    }
    query_thread_log = {
      "@remove" = "remove"
    }
    query_log = {
      "@remove" = "remove"
    }
    query_views_log = {
      "@remove" = "remove"
    }
    part_log = {
      "@remove" = "remove"
    }
    trace_log = {
      "@remove" = "remove"
    }
    crash_log = {
      "@remove" = "remove"
    }

    zookeeper = {
      node = [
        for _, member in local.members :
        {
          host   = "${member}.${local.peer_service_endpoint}"
          port   = local.ports.keeper
          secure = 1
        }
      ]
    }
    macros = {
      shard = "1"
    }
    default_profile      = "default"
    default_replica_path = "/clickhouse/tables/{shard}/{database}/{table}"
    default_replica_name = "{replica}"
    distributed_ddl = {
      profile = "default"
    }

    remote_servers = {
      "@replace" = "replace"
      default = {
        shard = {
          internal_replication = true
          replica = [
            for _, member in local.members :
            {
              host   = "${member}.${local.peer_service_endpoint}"
              port   = local.ports.clickhouse
              secure = 1
            }
          ]
        }
      }
    }
  })

  keeper_config = merge({
    tcp_port_secure       = local.ports.keeper
    async_replication     = true
    log_storage_disk      = "log_s3_plain"
    snapshot_storage_disk = "snapshot_s3_plain"
    state_storage_disk    = "state_s3_plain"
    coordination_settings = {
      force_sync = false
    }
    feature_flags = {
      check_not_exists     = 1
      create_if_not_exists = 1
    }
    raft_configuration = {
      secure = true
      server = [
        for i, member in local.members :
        {
          id       = i + 1
          hostname = "${member}.${local.peer_service_endpoint}"
          port     = local.ports.raft
        }
      ]
    }
  }, var.extra_keeper_config)
}

module "metadata" {
  source      = "../metadata"
  name        = local.name
  namespace   = local.namespace
  release     = var.release
  app_version = split(":", var.images.clickhouse)[1]
  manifests = {
    "templates/service.yaml"      = module.service.manifest
    "templates/service-peer.yaml" = module.service-peer.manifest
    "templates/secret.yaml"       = module.secret.manifest
    "templates/statefulset.yaml"  = module.statefulset-jfs.statefulset
    "templates/secret-jfs.yaml"   = module.statefulset-jfs.secret
  }
}

module "secret" {
  source  = "../secret"
  name    = local.name
  app     = local.name
  release = var.release
  data = merge({
    basename(local.ca_cert_path) = chomp(var.ca.cert_pem)
    }, {
    for i, member in local.members :
    "cert-${member}" => chomp(tls_locally_signed_cert.clickhouse[member].cert_pem)
    }, {
    for i, member in local.members :
    "key-${member}" => chomp(tls_private_key.clickhouse[member].private_key_pem)
    }, {
    for i, member in local.members :
    "config-${member}" => yamlencode(merge(local.clickhouse_config, {
      keeper_server = merge(local.keeper_config, {
        server_id = i + 1
      })
      macros = merge(local.clickhouse_config.macros, {
        replica = "replica_${i + 1}"
      })
      interserver_http_host = "${member}.${local.peer_service_endpoint}"
    }))
  })
}

module "service" {
  source  = "../service"
  name    = local.name
  app     = local.name
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
        name       = "interserver"
        port       = local.clickhouse_config.interserver_https_port
        protocol   = "TCP"
        targetPort = local.clickhouse_config.interserver_https_port
      },
      {
        name       = "clickhouse"
        port       = local.ports.clickhouse
        protocol   = "TCP"
        targetPort = local.ports.clickhouse
      },
    ]
  }
}

module "service-peer" {
  source  = "../service"
  name    = local.peer_name
  app     = local.name
  release = var.release
  spec = {
    type                     = "ClusterIP"
    clusterIP                = "None"
    publishNotReadyAddresses = true
    ports = [
      {
        name       = "clickhouse"
        port       = local.ports.clickhouse
        protocol   = "TCP"
        targetPort = local.ports.clickhouse
      },
      {
        name       = "keeper"
        port       = local.ports.keeper
        protocol   = "TCP"
        targetPort = local.ports.keeper
      },
      {
        name       = "raft"
        port       = local.ports.raft
        protocol   = "TCP"
        targetPort = local.ports.raft
      },
    ]
  }
}

module "statefulset-jfs" {
  source = "../statefulset_jfs"
  ## jfs settings
  jfs_image                          = var.images.jfs
  jfs_mount_path                     = local.clickhouse_config.path
  jfs_minio_bucket_endpoint          = var.jfs_minio_bucket_endpoint
  jfs_minio_access_key_id            = var.jfs_minio_access_key_id
  jfs_minio_secret_access_key        = var.jfs_minio_secret_access_key
  litestream_image                   = var.images.litestream
  litestream_minio_bucket_endpoint   = var.litestream_minio_bucket_endpoint
  litestream_minio_access_key_id     = var.litestream_minio_access_key_id
  litestream_minio_secret_access_key = var.litestream_minio_secret_access_key
  ##
  name     = local.name
  app      = local.name
  release  = var.release
  replicas = var.replicas
  affinity = var.affinity
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  spec = {
    serviceName          = local.peer_name
    minReadySeconds      = 30
    volumeClaimTemplates = var.volume_claim_templates
    podManagementPolicy  = "Parallel"
  }
  template_spec = {
    containers = [
      {
        name  = local.name
        image = var.images.clickhouse
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          mountpoint ${local.clickhouse_config.path}
          rm -f ${local.clickhouse_config.path}/status

          mkdir -p ${local.clickhouse_config.path}/flags
          touch ${local.clickhouse_config.path}/flags/force_restore_data

          exec clickhouse-server \
            -C ${local.base_path}/config.xml
          EOF
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
        volumeMounts = concat([
          {
            name        = "secret"
            mountPath   = local.config_path
            subPathExpr = "config-$(POD_NAME)"
          },
          {
            name        = "secret"
            mountPath   = local.cert_path
            subPathExpr = "cert-$(POD_NAME)"
          },
          {
            name        = "secret"
            mountPath   = local.key_path
            subPathExpr = "key-$(POD_NAME)"
          },
          {
            name      = "secret"
            mountPath = local.ca_cert_path
            subPath   = basename(local.ca_cert_path)
          },
        ], var.extra_volume_mounts)
        ports = [
          {
            containerPort = local.clickhouse_config.mysql_port
          },
          {
            containerPort = local.clickhouse_config.postgresql_port
          },
          {
            containerPort = local.clickhouse_config.https_port
          },
          {
            containerPort = local.clickhouse_config.interserver_https_port
          },
          {
            containerPort = local.ports.clickhouse
          },
          {
            containerPort = local.ports.keeper
          },
        ]
        livenessProbe = {
          tcpSocket = {
            port = local.clickhouse_config.http_port
          }
          initialDelaySeconds = 10
        }
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.clickhouse_config.http_port
            path   = "/ping"
          }
          initialDelaySeconds = 10
        }
      },
    ]
    volumes = concat([
      {
        name = "secret"
        secret = {
          secretName  = module.secret.name
          defaultMode = 493
        }
      },
    ], var.extra_volumes)
  }
}