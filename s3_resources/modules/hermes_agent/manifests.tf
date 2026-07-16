locals {
  extra_envs = merge(var.extra_envs, {
    HERMES_HOME     = "/opt/data"
    API_SERVER_HOST = "0.0.0.0"
    API_SERVER_PORT = 8642
  })
  tmp_path = "/opt/data-tmp"
  uid      = 10000
  gid      = 10000

  files = merge({
    "config.yaml" = yamlencode(var.extra_configs)
    ".env"        = <<-EOF
%{~for k, v in local.extra_envs~}
${k}=${v}

%{~endfor~}
    EOF
  }, var.extra_files)

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
        name       = var.name
        port       = local.extra_envs.API_SERVER_PORT
        protocol   = "TCP"
        targetPort = local.extra_envs.API_SERVER_PORT
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
            port = local.extra_envs.API_SERVER_PORT
          },
        ]
      },
    ]
  }
}

module "deployment" {
  source = "../../../modules/deployment"

  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  affinity  = var.affinity
  replicas  = var.replicas
  annotations = merge({
    "checksum/secret"            = sha256(module.secret.manifest)
    "checksum/minio-user-secret" = sha256(module.minio-user-secret.manifest)
  })

  template_spec = {
    securityContext = {
      # uid/gid of hermes
      fsGroup = local.gid
    }
    resources = {
      requests = {
        memory = "4Gi"
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

          cp -rfL ${local.tmp_path}/. \
            ${local.extra_envs.HERMES_HOME}

          exec /init /opt/hermes/docker/main-wrapper.sh gateway run
          EOF
        ]
        env = [
          {
            name  = "TZ"
            value = lookup(var.extra_configs, "timezone", "UTC")
          },
        ]
        volumeMounts = concat([
          {
            name      = "data"
            mountPath = local.extra_envs.HERMES_HOME
          },
          {
            name      = "ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            readOnly  = true
          },
          {
            name      = "mcp-client-tls"
            mountPath = "${local.tmp_path}/.certs/mcp-client.crt"
            subPath   = "tls.crt"
          },
          {
            name      = "mcp-client-tls"
            mountPath = "${local.tmp_path}/.certs/mcp-client.key"
            subPath   = "tls.key"
          },
          ], [
          for f, _ in local.files :
          {
            name      = "config"
            mountPath = "${local.tmp_path}/${f}"
            subPath   = f
          }
        ])
        ports = [
          {
            containerPort = local.extra_envs.API_SERVER_PORT
          },
        ]
        startupProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.extra_envs.API_SERVER_PORT
            path   = "/health"
          }
          failureThreshold = 6
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.extra_envs.API_SERVER_PORT
            path   = "/health"
          }
          initialDelaySeconds = 10
          timeoutSeconds      = 2
        }
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.extra_envs.API_SERVER_PORT
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
        name = "mcp-client-tls"
        secret = {
          secretName = "${var.name}-client-tls"
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