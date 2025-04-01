locals {
  peer_name            = "${var.name}-peer"
  s3_clickhouse_prefix = "clickhouse"

  members = [
    for i in range(var.replicas) :
    "${var.name}-${i}"
  ]
  process_user  = "clickhouse"
  process_group = "clickhouse"

  cache_path   = "/var/tmp/clickhouse"
  base_path    = "/etc/clickhouse-server"
  config_path  = "${local.base_path}/config.d/server.yaml"
  users_path   = "${local.base_path}/users.d/users.yaml"
  cert_path    = "${local.base_path}/certs/server.crt"
  key_path     = "${local.base_path}/certs/server.key"
  ca_cert_path = "${local.base_path}/certs/ca.crt"
  ports = merge({
    keeper = 9281
    raft   = 9444
  }, var.ports)

  clickhouse_config = merge({
    mysql_port             = 9004
    postgresql_port        = 9005
    http_port              = 8123
    https_port             = 8443
    interserver_https_port = 9010
    interserver_http_port  = { "@remove" = "1" }
    tcp_port_secure        = local.ports.clickhouse
    path                   = "/var/lib/clickhouse"
    listen_reuse_port      = 1
    }, var.extra_clickhouse_config, {
    logger = {
      "@replace" = "1"
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
        certificateFile = local.cert_path
        privateKeyFile  = local.key_path
        caConfig        = local.ca_cert_path
      }
    }
    storage_configuration = {
      "@replace" = "1"
      disks = {
        s3 = {
          type                 = "object_storage"
          object_storage_type  = "s3"
          metadata_type        = "plain_rewritable"
          endpoint             = "${var.s3_endpoint}/${var.s3_bucket}/${local.s3_clickhouse_prefix}/s3/"
          access_key_id        = var.s3_access_key_id
          secret_access_key    = var.s3_secret_access_key
          region               = ""
          support_batch_delete = true
        }
        # needs old formatting for keeper storage configs
        log_s3_plain = {
          type              = "s3_plain"
          endpoint          = "${var.s3_endpoint}/${var.s3_bucket}/${local.s3_clickhouse_prefix}/log/"
          access_key_id     = var.s3_access_key_id
          secret_access_key = var.s3_secret_access_key
          region            = ""
        }
        log_local = {
          type = "local"
          path = "${local.cache_path}/coordination/logs/"
        }
        snapshot_s3_plain = {
          type              = "s3_plain"
          endpoint          = "${var.s3_endpoint}/${var.s3_bucket}/${local.s3_clickhouse_prefix}/snapshot/"
          access_key_id     = var.s3_access_key_id
          secret_access_key = var.s3_secret_access_key
          region            = ""
        }
        state_s3_plain = {
          type              = "s3_plain"
          endpoint          = "${var.s3_endpoint}/${var.s3_bucket}/${local.s3_clickhouse_prefix}/state/"
          access_key_id     = var.s3_access_key_id
          secret_access_key = var.s3_secret_access_key
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
    asynchronous_metric_log = { "@remove" = "1" }
    blob_storage_log        = { "@remove" = "1" }
    crash_log               = { "@remove" = "1" }
    error_log               = { "@remove" = "1" }
    latency_log             = { "@remove" = "1" }
    metric_log              = { "@remove" = "1" }
    opentelemetry_span_log  = { "@remove" = "1" }
    part_log                = { "@remove" = "1" }
    query_log               = { "@remove" = "1" }
    query_metric_log        = { "@remove" = "1" }
    query_thread_log        = { "@remove" = "1" }
    query_views_log         = { "@remove" = "1" }
    session_log             = { "@remove" = "1" }
    text_log                = { "@remove" = "1" }
    trace_log               = { "@remove" = "1" }
    zookeeper_log           = { "@remove" = "1" }

    zookeeper = {
      node = [
        for _, member in local.members :
        {
          host   = "${member}.${local.peer_name}.${var.namespace}"
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
      "@replace" = "1"
      default = {
        shard = {
          internal_replication = true
          replica = [
            for _, member in local.members :
            {
              host   = "${member}.${local.peer_name}.${var.namespace}"
              port   = local.ports.clickhouse
              secure = 1
            }
          ]
        }
      }
    }

    prometheus = {
      "@replace"           = "1"
      port                 = local.ports.metrics
      endpoint             = "/metrics"
      metrics              = true
      asynchronous_metrics = true
      events               = true
      errors               = true
    }
  })

  keeper_config = merge({
    tcp_port_secure       = local.ports.keeper
    async_replication     = true
    log_storage_disk      = "log_local"
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
          hostname = "${member}.${local.peer_name}.${var.namespace}"
          port     = local.ports.raft
        }
      ]
    }
  }, var.extra_keeper_config)
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.clickhouse)[1]
  manifests = merge(module.s3fs.chart.manifests, {
    "templates/service.yaml"      = module.service.manifest
    "templates/service-peer.yaml" = module.service-peer.manifest
    "templates/secret.yaml"       = module.secret.manifest
  })
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = merge({
    basename(local.ca_cert_path) = chomp(var.ca.cert_pem)
    basename(local.users_path)   = yamlencode(var.extra_users_config)
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
      interserver_http_host = "${member}.${local.peer_name}.${var.namespace}"
    }))
  })
}

module "service" {
  source  = "../../../modules/service"
  name    = var.name
  app     = var.name
  release = var.release
  annotations = {
    "external-dns.alpha.kubernetes.io/hostname" = var.service_hostname
    "prometheus.io/scrape"                      = "true"
    "prometheus.io/port"                        = tostring(local.ports.metrics)
  }
  spec = {
    type              = "LoadBalancer"
    loadBalancerIP    = "0.0.0.0"
    loadBalancerClass = var.loadbalancer_class_name
    ports = [
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
      {
        name       = "https"
        port       = local.clickhouse_config.https_port
        protocol   = "TCP"
        targetPort = local.clickhouse_config.https_port
      },
      {
        name       = "metrics"
        port       = local.ports.metrics
        protocol   = "TCP"
        targetPort = local.ports.metrics
      },
    ]
  }
}

module "service-peer" {
  source  = "../../../modules/service"
  name    = local.peer_name
  app     = var.name
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
        name       = "https"
        port       = local.clickhouse_config.https_port
        protocol   = "TCP"
        targetPort = local.clickhouse_config.https_port
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

module "s3fs" {
  source = "../statefulset_s3fs"
  ## s3 config
  s3_endpoint          = var.s3_endpoint
  s3_bucket            = var.s3_bucket
  s3_prefix            = "$(POD_NAME)"
  s3_access_key_id     = var.s3_access_key_id
  s3_secret_access_key = var.s3_secret_access_key
  s3_mount_path        = local.clickhouse_config.path
  s3_mount_extra_args  = var.s3_mount_extra_args
  images = {
    s3fs = var.images.s3fs
  }
  ##
  name     = var.name
  app      = var.name
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
        name  = var.name
        image = var.images.clickhouse
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          until mountpoint ${local.clickhouse_config.path}; do
          sleep 1
          done

          mkdir -p \
            ${local.cache_path}/coordination \
            ${local.cache_path}/preprocessed_configs \
            ${local.cache_path}/tmp
          chown -R ${local.process_user}:${local.process_group} \
            ${local.cache_path}
          ln -sf \
            ${local.cache_path}/* \
            ${local.clickhouse_config.path}

          exec clickhouse su ${local.process_user}:${local.process_group} \
            clickhouse-server \
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
            mountPath = local.users_path
            subPath   = basename(local.users_path)
          },
          {
            name      = "secret"
            mountPath = local.ca_cert_path
            subPath   = basename(local.ca_cert_path)
          },
        ], var.extra_volume_mounts)
        ports = [
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