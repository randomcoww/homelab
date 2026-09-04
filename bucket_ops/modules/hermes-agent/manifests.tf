locals {
  config_envs = merge(var.extra_config_envs, {
    HERMES_HOME                 = "/opt/data"
    API_SERVER_ENABLED          = true
    API_SERVER_HOST             = "0.0.0.0"
    API_SERVER_PORT             = 8642
    HERMES_STREAM_READ_TIMEOUT  = 1800
    HERMES_STREAM_STALE_TIMEOUT = 1800
    HERMES_CRON_TIMEOUT         = 1800
    GATEWAY_ALLOW_ALL_USERS     = true
    # custom vars #
    INTERNAL_CLIENT_CERT_PATH = "/opt/tls/.certs/mcp-client.crt"
    INTERNAL_CLIENT_KEY_PATH  = "/opt/tls/.certs/mcp-client.key"
  })
  agent_envs = merge({
    HERMES_UID            = 10000
    HERMES_GID            = 10000
    HERMES_DASHBOARD      = false
    HERMES_DASHBOARD_PORT = 9119
    HERMES_DASHBOARD_HOST = "0.0.0.0"
    SSL_CERT_FILE         = "/etc/ssl/certs/ca-certificates.crt"
  }, var.extra_agent_envs)
  webui_envs = merge({
    WANTED_UID                        = local.agent_envs.HERMES_UID
    WANTED_GID                        = local.agent_envs.HERMES_GID
    HERMES_WEBUI_SKIP_ONBOARDING      = 1
    HERMES_WEBUI_HOST                 = "0.0.0.0"
    HERMES_WEBUI_PORT                 = 8787
    HERMES_WEBUI_STATE_DIR            = "${local.config_envs.HERMES_HOME}/webui"
    HERMES_WEBUI_DEFAULT_WORKSPACE    = "${local.config_envs.HERMES_HOME}/workspace"
    HERMES_WEBUI_AGENT_DIR            = "/opt/hermes"
    HERMES_WEBUI_CHAT_BACKEND         = "local" # params below are only used in gateway mode
    HERMES_WEBUI_GATEWAY_BASE_URL     = "http://127.0.0.1:${local.config_envs.API_SERVER_PORT}"
    HERMES_WEBUI_GATEWAY_USE_RUNS_API = true
    SSL_CERT_FILE                     = "/etc/ssl/certs/ca-certificates.crt"
  }, var.extra_webui_envs)

  overlay_paths = [
    ".cache",
    ".local",
    ".ssh",
    "cache",
    "home",
    "lazy-packages",
    "logs",
    "webui",
  ]

  # mounts for both agent and webui
  common_volume_mounts = concat([
    {
      name      = "hermes-home"
      mountPath = local.config_envs.HERMES_HOME
      subPath   = "mount"
    },
    {
      name      = "ca-trust-bundle"
      mountPath = local.agent_envs.SSL_CERT_FILE
      readOnly  = true
    },
    {
      name      = "internal-client-tls"
      mountPath = local.config_envs.INTERNAL_CLIENT_CERT_PATH
      subPath   = "tls.crt"
      readOnly  = true
    },
    {
      name      = "internal-client-tls"
      mountPath = local.config_envs.INTERNAL_CLIENT_KEY_PATH
      subPath   = "tls.key"
      readOnly  = true
    },
    ], [
    for _, p in local.overlay_paths :
    {
      name      = "tmpfs"
      mountPath = "${local.config_envs.HERMES_HOME}/${p}"
      subPath   = p
    }
  ])

  # mount configs here to copy on init
  home_copy_path = "/var/tmp/hermes/config"
  config_files = {
    ssh_known_hosts = {
      path    = ".ssh/known_hosts"
      content = "@cert-authority * ${chomp(var.ssh_ca.public_key_openssh)}"
    }
    ssh_private_key = {
      path    = ".ssh/id_ecdsa"
      content = tls_private_key.ssh-client.private_key_pem
    }
    ssh_cert = {
      path    = ".ssh/id_ecdsa-cert.pub"
      content = ssh_user_cert.ssh-client.cert_authorized_key
    }
    ssh_config = {
      path    = ".ssh/config"
      content = <<-EOF
        Host *
          User ${var.ssh_user}
          IdentityFile "${local.config_envs.HERMES_HOME}/.ssh/id_ecdsa"
          PubkeyAuthentication yes
        EOF
    }
    config = {
      path = "config.yaml"
      content = yamlencode(merge(var.extra_configs, {
        mcp_servers = merge(lookup(var.extra_configs, "mcp_servers", {}), {
          "${var.name}-litestream" = {
            url             = "http://127.0.0.1:${local.litestream_mcp_port}"
            timeout         = 300
            connect_timeout = 30
          }
        })
      }))
    }
    env = {
      path    = ".env"
      content = <<-EOF
%{for k, v in local.config_envs}${k}=${v}
%{endfor~}
EOF
    }
  }

  litestream_symlink_path = "/var/tmp/hermes/db"
  litestream_targets = [ # mount these to tmpfs for performance
    "state.db",
    "kanban.db",
    "projects.db",
    "response_store.db",
    "verification_evidence.db",
  ]
  litestream_mcp_port = 3001

  juicefs_name              = "${var.name}-juicefs"
  juicefs_postgres_database = "juicefs"
  juicefs_postgres_username = "juicefs"
}

resource "random_password" "juicefs-postgres-password" {
  length  = 32
  special = false
}

module "secret" {
  source    = "../../../modules/secret"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    for k, v in local.config_files :
    k => v.content
  }
}

module "env-secret" {
  source    = "../../../modules/secret"
  name      = "${var.name}-env"
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    for k, v in merge(local.webui_envs, local.config_envs) :
    tostring(k) => tostring(v)
  }
}

module "juicefs-secret" {
  source    = "../../../modules/secret"
  name      = local.juicefs_name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    # juicefs params
    name = var.name
    metaurl = join("&", [
      "postgres://${local.juicefs_postgres_username}:${random_password.juicefs-postgres-password.result}@${local.juicefs_name}-pg-rw.${var.namespace}/${local.juicefs_postgres_database}?sslmode=verify-full",
      "sslrootcert=${var.juicefs_client_tls_path}/ca.crt",
      "sslcert=${var.juicefs_client_tls_path}/tls.crt",
      "sslkey=${var.juicefs_client_tls_path}/tls.key",
    ])
    storage    = "minio"
    bucket     = "${var.minio_endpoint}/${var.minio_bucket}"
    access-key = var.minio_user.id
    secret-key = var.minio_user.secret
    format-options = join(",", [
      "trash-days=1", # set to greater than metadata backup period
      "block-size=4096",
    ])

    # cngp params
    username = local.juicefs_postgres_username
    password = random_password.juicefs-postgres-password.result
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
        name       = "webui"
        port       = local.webui_envs.HERMES_WEBUI_PORT
        protocol   = "TCP"
        targetPort = local.webui_envs.HERMES_WEBUI_PORT
      },
      {
        name       = "apiserver"
        port       = local.config_envs.API_SERVER_PORT
        protocol   = "TCP"
        targetPort = local.config_envs.API_SERVER_PORT
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
            port = local.webui_envs.HERMES_WEBUI_PORT
          },
        ]
      },
      {
        matches = [
          {
            path = {
              type  = "PathPrefix"
              value = "/v1"
            }
          },
        ]
        backendRefs = [
          {
            name = module.service.name
            port = local.config_envs.API_SERVER_PORT
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
    mcp-addr = "127.0.0.1:${local.litestream_mcp_port}"
    dbs = [
      for _, db in local.litestream_targets :
      {
        path                = "${local.litestream_symlink_path}/${db}"
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
  mount_path            = local.litestream_symlink_path
  mount_path_volume_ref = "${var.name}-litestream-data"
  s3_access_key_ref = {
    name = module.minio-user-secret.name
    key  = "AWS_ACCESS_KEY_ID"
  }
  s3_secret_key_ref = {
    name = module.minio-user-secret.name
    key  = "AWS_SECRET_ACCESS_KEY"
  }
  litestream_container_params = {
    securityContext = {
      # run litestream as hermes user
      runAsUser  = local.agent_envs.HERMES_UID
      runAsGroup = local.agent_envs.HERMES_GID
    }
    ports = [
      {
        containerPort = local.litestream_mcp_port
      },
    ]
  }

  template_spec = {
    terminationGracePeriodSeconds = 60
    resources = {
      requests = {
        memory = "1Gi"
      }
      limits = {
        memory = "2Gi"
      }
    }
    # do not use fsGroup with juicefs
    initContainers = [
      {
        name  = "${var.name}-config"
        image = "${var.images.hermes-agent.repository}:${var.images.hermes-agent.tag}"
        command = [
          "bash",
          "-c",
          <<-EOF
set -xe
cd ${local.config_envs.HERMES_HOME}
chown ${local.agent_envs.HERMES_UID}:${local.agent_envs.HERMES_GID} .

runuser -p -u hermes -- bash <<EOT
set -x

# Symlink sqlite DBs to litestream replication path
%{for _, d in distinct([for _, db in local.litestream_targets : dirname(db) if dirname(db) != "."])}mkdir -p ${d}
%{endfor~}
%{for _, db in local.litestream_targets}ln -sf ${local.litestream_symlink_path}/${db} ${db}
%{endfor~}

# Config.yaml and .env need to be writeable. Copy from mount to hermes home.
%{for _, d in distinct([for _, f in local.config_files : dirname(f.path) if dirname(f.path) != "."])}mkdir -p ${d}
%{endfor~}
%{for _, f in local.config_files}cp -afL ${local.home_copy_path}/${f.path} ${f.path}
%{endfor~}

# Update permissions for ssh files
chmod -R 600 .ssh/*
EOT
EOF
        ]
        volumeMounts = concat(local.common_volume_mounts, [
          for k, v in local.config_files :
          {
            name      = "config"
            mountPath = "${local.home_copy_path}/${v.path}"
            subPath   = k
          }
        ])
      }
    ]
    containers = [
      {
        name  = var.name
        image = "${var.images.hermes-agent.repository}:${var.images.hermes-agent.tag}"
        args = [
          "sleep",
          "infinity",
        ]
        env = [
          for k, v in local.agent_envs :
          {
            name  = tostring(k)
            value = tostring(v)
          }
        ]
        volumeMounts = concat(local.common_volume_mounts, [
        ])
        ports = [
          {
            containerPort = local.config_envs.API_SERVER_PORT
          },
          {
            containerPort = local.agent_envs.HERMES_DASHBOARD_PORT
          },
        ]
        startupProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.config_envs.API_SERVER_PORT
            path   = "/health"
          }
          failureThreshold = 6
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.config_envs.API_SERVER_PORT
            path   = "/health"
          }
          initialDelaySeconds = 10
          timeoutSeconds      = 2
        }
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.config_envs.API_SERVER_PORT
            path   = "/health"
          }
        }
      },
      {
        name  = "${var.name}-webui"
        image = "${var.images.hermes-webui.repository}:${var.images.hermes-webui.tag}"
        envFrom = [
          {
            secretRef = {
              name = module.env-secret.name
            }
          },
        ]
        volumeMounts = concat(local.common_volume_mounts, [
          {
            name      = "agent"
            mountPath = local.webui_envs.HERMES_WEBUI_AGENT_DIR
            subPath   = "opt/hermes"
          },
          {
            name      = "tmpfs"
            mountPath = "/home/hermeswebui/.ssh"
            subPath   = ".ssh"
          },
        ])
        ports = [
          {
            containerPort = local.webui_envs.HERMES_WEBUI_PORT
          },
        ]
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.webui_envs.HERMES_WEBUI_PORT
            path   = "/health"
          }
          initialDelaySeconds = 10
          timeoutSeconds      = 2
        }
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.webui_envs.HERMES_WEBUI_PORT
            path   = "/health"
          }
        }
      },
    ]
    volumes = [
      {
        name = "hermes-home"
        persistentVolumeClaim = {
          claimName = "${var.name}-${var.minio_bucket}"
        }
      },
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
        name = "tmpfs"
        emptyDir = {
          medium = "Memory"
        }
      },
      {
        name = "${var.name}-litestream-data"
        emptyDir = {
          medium = "Memory"
        }
      },
      {
        name = "internal-client-tls"
        csi = {
          driver   = "csi.cert-manager.io"
          readOnly = true
          volumeAttributes = {
            "csi.cert-manager.io/issuer-name"   = var.ca_issuer_name
            "csi.cert-manager.io/issuer-kind"   = "ClusterIssuer"
            "csi.cert-manager.io/key-algorithm" = "ECDSA"
            "csi.cert-manager.io/key-size"      = "521"
            "csi.cert-manager.io/key-usages" = join(",", [
              "digital signature",
              "key encipherment",
            ])
            "csi.cert-manager.io/fs-group" : tostring(local.agent_envs.HERMES_GID)
          }
        }
      },
      {
        name = "agent"
        image = {
          reference = "${var.images.hermes-agent.repository}:${var.images.hermes-agent.tag}"
        }
      },
    ]
  }
}

module "statefulset" {
  source = "../../../modules/statefulset"

  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  affinity  = var.affinity
  replicas  = var.replicas
  annotations = {
    "checksum/secret"            = sha256(module.secret.manifest)
    "checksum/env-secret"        = sha256(module.env-secret.manifest)
    "checksum/juicefs-secret"    = sha256(module.juicefs-secret.manifest)
    "checksum/minio-user-secret" = sha256(module.minio-user-secret.manifest)
  }
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
  template_spec = merge(module.litestream-overlay.template_spec, {
    terminationGracePeriodSeconds = 60
  })
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