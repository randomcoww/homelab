locals {
  env = merge(var.extra_envs, {
    HERMES_HOME     = "/opt/data"
    API_SERVER_HOST = "0.0.0.0"
    API_SERVER_PORT = 8642
  })
  data_path = "/opt/data-persist"
  tmp_path  = "/opt/data-tmp"
  uid       = 10000
  gid       = 10000
}

module "secret" {
  source    = "../../../modules/secret"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    "config.yaml" = yamlencode(var.extra_configs)
    ".env"        = <<-EOF
%{~for k, v in local.env~}
${k}=${v}

%{~endfor~}
    EOF
    "SOUL.md"     = var.soul
  }
}

module "service" {
  source    = "../../../modules/service"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = var.name
        port       = local.env.API_SERVER_PORT
        protocol   = "TCP"
        targetPort = local.env.API_SERVER_PORT
      },
    ]
  }
}

module "httproute" {
  source    = "../../../modules/httproute"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  spec = {
    parentRefs = [
      merge({
        kind = "Gateway"
      }, var.gateway_ref),
    ]
    hostnames = [
      var.ingress_hostname,
    ]
    rules = [
      {
        matches = [
          {
            path = {
              type  = "PathPrefix"
              value = "/"
            }
          },
        ]
        backendRefs = [
          {
            name = module.service.name
            port = local.env.API_SERVER_PORT
          },
        ]
      },
    ]
  }
}

module "litestream-overlay" {
  source = "../litestream_overlay"

  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  images = {
    litestream = var.images.litestream
  }
  litestream_config = {
    dbs = [
      for _, db in [
        "state.db",
        "kanban.db",
        "response_store.db",
        "memory_store.db",
      ] :
      {
        path                = "${local.env.HERMES_HOME}/${db}"
        monitor-interval    = "1s"
        checkpoint-interval = "60s"
        replica = {
          type          = "s3"
          endpoint      = var.minio_endpoint
          bucket        = var.minio_bucket
          path          = "$POD_NAME/${db}"
          sync-interval = "1s"
          part-size     = "50MB"
          concurrency   = 10
          auto-recover  = true
        }
      }
    ]
  }
  mount_path       = local.env.HERMES_HOME
  s3_access_secret = module.minio-user-secret.name

  template_spec = {
    securityContext = {
      # uid/gid of hermes
      fsGroup = local.gid
    }
    resources = {
      requests = {
        memory = "6Gi"
      }
      limits = {
        memory = "6Gi"
      }
    }
    containers = [
      {
        name  = var.name
        image = var.images.hermes_agent
        command = [
          "bash",
          "-c",
          <<-EOF
          set -xe

          mkdir -p \
            ${local.data_path}/sessions \
            ${local.data_path}/memories \
            ${local.data_path}/cache \
            ${local.data_path}/cron \
            ${local.data_path}/skills \
            ${local.data_path}/pairing \
            ${local.data_path}/workspace

          ln -sf ${local.data_path}/* \
            ${local.env.HERMES_HOME}/
          cp -rfL ${local.tmp_path}/. \
            ${local.env.HERMES_HOME}/
          chown -R ${local.uid}:${local.gid} \
            ${local.env.HERMES_HOME} \
            ${local.data_path}

          exec /init /opt/hermes/docker/main-wrapper.sh gateway run
          EOF
        ]
        env = [
          {
            name  = "TZ"
            value = lookup(var.extra_configs, "timezone", "UTC")
          },
        ]
        volumeMounts = [
          {
            name      = "ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            readOnly  = true
          },
          {
            name      = "config"
            mountPath = "${local.tmp_path}/.env"
            subPath   = ".env"
          },
          {
            name      = "config"
            mountPath = "${local.tmp_path}/config.yaml"
            subPath   = "config.yaml"
          },
          {
            name      = "config"
            mountPath = "${local.tmp_path}/SOUL.md"
            subPath   = "SOUL.md"
          },
        ]
        ports = [
          {
            containerPort = local.env.API_SERVER_PORT
          },
        ]
      },
    ]
    volumes = [
      {
        name = "ca-trust-bundle"
        hostPath = {
          path = "/etc/ssl/certs/ca-certificates.crt"
          type = "File"
        }
      },
      {
        name = "config"
        secret = {
          secretName  = module.secret.name
          defaultMode = 493
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

module "juicefs-overlay" {
  source = "../juicefs_overlay"

  name                = var.name
  namespace           = var.namespace
  app                 = var.name
  release             = var.release
  mount_path          = local.data_path
  minio_endpoint      = var.minio_endpoint
  minio_bucket        = var.minio_bucket
  minio_prefix        = "jfs"
  minio_access_secret = module.minio-user-secret.name
  mount_extra_opts = [
    "user_id=${local.uid}",
    "group_id=${local.gid}",
  ]
  capacity_gb = 32
  images = {
    juicefs    = var.images.juicefs
    litestream = var.images.litestream
  }
  template_spec = module.litestream-overlay.template_spec
}

module "statefulset" {
  source = "../../../modules/statefulset"

  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  affinity  = var.affinity
  replicas  = var.replicas
  annotations = merge({
    "checksum/secret"            = sha256(module.secret.manifest)
    "checksum/minio-user-secret" = sha256(module.minio-user-secret.manifest)
    }, {
    for i, m in module.litestream-overlay.additional_manifests :
    "checksum/litestream-${i}" => sha256(m)
    }, {
    for i, m in module.juicefs-overlay.additional_manifests :
    "checksum/juicefs-${i}" => sha256(m)
  })
  spec = {
    volumeClaimTemplates = [
      {
        metadata = {
          name = "${var.name}-juicefs-litestream-data" # persist path used for juicefs db
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
  template_spec = module.juicefs-overlay.template_spec
}

module "minio-user-secret" {
  source    = "../../../modules/secret"
  name      = "${var.name}-minio-user-secret"
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = merge({
    AWS_ACCESS_KEY_ID     = var.minio_user.id
    AWS_SECRET_ACCESS_KEY = var.minio_user.secret
  })
}