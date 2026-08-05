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
    # mnemosyne vars #
    MNEMOSYNE_HOST_LLM_ENABLED = true
    # custom vars #
    INTERNAL_CLIENT_CERT_PATH = "/opt/tls/.certs/mcp-client.crt"
    INTERNAL_CLIENT_KEY_PATH  = "/opt/tls/.certs/mcp-client.key"
  })
  agent_envs = merge({
    HERMES_UID            = 10000
    HERMES_GID            = 10000
    HERMES_DASHBOARD      = true
    HERMES_DASHBOARD_PORT = 9119
    HERMES_DASHBOARD_HOST = "0.0.0.0"
    SSL_CERT_FILE         = "/etc/ssl/certs/ca-certificates.crt"
  }, var.extra_agent_envs)

  files = {
    "config.yaml" = yamlencode(var.extra_configs)
    ".env"        = <<-EOF
%{for k, v in local.config_envs}${k}=${v}
%{endfor~}
EOF
  }

  # mounts for both agent and webui
  common_volume_mounts = [
    {
      name      = "data"
      mountPath = local.config_envs.HERMES_HOME
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
    {
      name      = "tmp"
      mountPath = "${local.config_envs.HERMES_HOME}/logs"
      subPath   = "logs"
    },
  ]

  tmp_path                  = "/tmp/hermes-config"
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
  data      = local.files
}

module "juicefs-secret" {
  source    = "../../../modules/secret"
  name      = "${var.name}-juicefs"
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    # juicefs params
    name       = var.name
    metaurl    = "postgres://${local.juicefs_postgres_username}:${random_password.juicefs-postgres-password.result}@${var.name}-juicefs-pg-rw.${var.namespace}/${local.juicefs_postgres_database}"
    storage    = "minio"
    bucket     = "${var.minio_endpoint}/${var.minio_bucket}"
    access-key = var.minio_user.id
    secret-key = var.minio_user.secret
    format-options = join(",", [
      "trash-days=0",
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
        port       = local.agent_envs.HERMES_DASHBOARD_PORT
        protocol   = "TCP"
        targetPort = local.agent_envs.HERMES_DASHBOARD_PORT
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
            port = local.agent_envs.HERMES_DASHBOARD_PORT
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
    "checksum/minio-user-secret" = sha256(module.minio-user-secret.manifest)
    "checksum/juicefs-secret"    = sha256(module.juicefs-secret.manifest)
  }
  template_spec = {
    resources = {
      requests = {
        memory = "4Gi"
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

rm -f \
  ${local.config_envs.HERMES_HOME}/config.yaml.bak-* \
  ${local.config_envs.HERMES_HOME}/.env.bak-*

cp -afL ${local.tmp_path}/. \
  ${local.config_envs.HERMES_HOME}

chown ${local.agent_envs.HERMES_UID}:${local.agent_envs.HERMES_GID} \
%{for f, _ in local.files}  ${local.config_envs.HERMES_HOME}/${f} \
%{endfor~}
  ${local.config_envs.HERMES_HOME}
EOF
        ]
        volumeMounts = concat([
          {
            name      = "data"
            mountPath = local.config_envs.HERMES_HOME
          },
          ], [
          for f, _ in local.files :
          {
            name      = "config"
            mountPath = "${local.tmp_path}/${f}"
            subPath   = f
          }
        ])
      }
    ]
    containers = [
      {
        name  = var.name
        image = "${var.images.hermes-agent.repository}:${var.images.hermes-agent.tag}"
        args = [
          "gateway",
          "run",
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
    ]
    volumes = [
      {
        name = "data"
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
        name = "tmp"
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
    ]
  }
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