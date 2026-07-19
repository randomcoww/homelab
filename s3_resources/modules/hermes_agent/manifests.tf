locals {
  hermes_envs = merge(var.hermes_envs, {
    HERMES_HOME        = "/opt/data"
    API_SERVER_ENABLED = true
    API_SERVER_HOST    = "0.0.0.0"
    API_SERVER_PORT    = 8642
    # custom vars #
    INTERNAL_CLIENT_CERT_PATH = "/opt/tls/.certs/mcp-client.crt"
    INTERNAL_CLIENT_KEY_PATH  = "/opt/tls/.certs/mcp-client.key"
  })
  envs = merge({
    HERMES_DASHBOARD      = true
    HERMES_DASHBOARD_PORT = 9119
    HERMES_DASHBOARD_HOST = "0.0.0.0"
    SSL_CERT_FILE         = "/etc/ssl/certs/ca-certificates.crt"
  }, var.extra_envs)

  tmp_path = "/opt/data-tmp"
  uid      = 10000
  gid      = 10000

  files = {
    "config.yaml" = yamlencode(var.extra_configs)
    ".env"        = <<-EOF
%{~for k, v in local.hermes_envs~}
${k}=${v}

%{~endfor~}
    EOF
  }
  juicefs_postgres_database = "juicefs"
  juicefs_postgres_user     = "juicefs"
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
    metaurl    = "postgres://${local.juicefs_postgres_user}:${random_password.juicefs-postgres-password.result}@${var.name}-pg-rw.${var.namespace}/${local.juicefs_postgres_database}"
    storage    = "minio"
    bucket     = "${var.minio_endpoint}/${var.minio_bucket}"
    access-key = var.minio_user.id
    secret-key = var.minio_user.secret
    format-options = join(",", [
      "trash-days=0",
      "block-size=4096",
    ])

    # cngp params
    username = local.juicefs_postgres_user
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
        name       = "dahsboard"
        port       = local.envs.HERMES_DASHBOARD_PORT
        protocol   = "TCP"
        targetPort = local.envs.HERMES_DASHBOARD_PORT
      },
      {
        name       = "apiserver"
        port       = local.hermes_envs.API_SERVER_PORT
        protocol   = "TCP"
        targetPort = local.hermes_envs.API_SERVER_PORT
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
            port = local.envs.HERMES_DASHBOARD_PORT
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
            port = local.hermes_envs.API_SERVER_PORT
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
    "checksum/secret"                     = sha256(module.secret.manifest)
    "checksum/minio-user-secret"          = sha256(module.minio-user-secret.manifest)
    "checksum/juicefs-secret"             = sha256(module.juicefs-secret.manifest)
    "secret.reloader.stakater.com/reload" = "${var.name}-client-tls"
  }
  template_spec = {
    resources = {
      requests = {
        memory = "4Gi"
      }
    }
    initContainers = [
      {
        name  = "${var.name}-config"
        image = var.images.hermes_agent
        command = [
          "bash",
          "-c",
          <<-EOF
          set -xe

          rm -f \
            ${local.hermes_envs.HERMES_HOME}/config.yaml.bak-* \
            ${local.hermes_envs.HERMES_HOME}/.env.bak-*

          cp -afL ${local.tmp_path}/. \
            ${local.hermes_envs.HERMES_HOME}

          chown ${local.uid}:${local.gid} \
            %{~for f, _ in local.files~}
            ${local.hermes_envs.HERMES_HOME}/${f} \
            %{~endfor~}
            ${local.hermes_envs.HERMES_HOME}
          EOF
        ]
        volumeMounts = concat([
          {
            name      = "data"
            mountPath = local.hermes_envs.HERMES_HOME
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
        image = var.images.hermes_agent
        args = [
          "gateway",
          "run",
        ]
        env = concat([
          for k, v in local.envs :
          {
            name  = tostring(k)
            value = tostring(v)
          }
          ], [
          {
            name  = "SSL_CERT_DIR"
            value = dirname(local.envs.SSL_CERT_FILE)
          },
        ])
        volumeMounts = [
          {
            name      = "data"
            mountPath = local.hermes_envs.HERMES_HOME
          },
          {
            name      = "ca-trust-bundle"
            mountPath = local.envs.SSL_CERT_FILE
            readOnly  = true
          },
          {
            name      = "client-tls"
            mountPath = local.hermes_envs.INTERNAL_CLIENT_CERT_PATH
            subPath   = "tls.crt"
          },
          {
            name      = "client-tls"
            mountPath = local.hermes_envs.INTERNAL_CLIENT_KEY_PATH
            subPath   = "tls.key"
          },
          {
            name      = "tmp"
            mountPath = "${local.hermes_envs.HERMES_HOME}/workspace"
            subPath   = "workspace"
          },
          {
            name      = "tmp"
            mountPath = "${local.hermes_envs.HERMES_HOME}/logs"
            subPath   = "logs"
          },
        ]
        ports = [
          {
            containerPort = local.envs.HERMES_DASHBOARD_PORT
          },
          {
            containerPort = local.hermes_envs.API_SERVER_PORT
          },
        ]
        startupProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.hermes_envs.API_SERVER_PORT
            path   = "/health"
          }
          failureThreshold = 6
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.hermes_envs.API_SERVER_PORT
            path   = "/health"
          }
          initialDelaySeconds = 10
          timeoutSeconds      = 2
        }
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.hermes_envs.API_SERVER_PORT
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
        name = "client-tls"
        secret = {
          secretName = "${var.name}-client-tls"
        }
      },
      {
        name = "tmp"
        emptyDir = {
          medium = "Memory"
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