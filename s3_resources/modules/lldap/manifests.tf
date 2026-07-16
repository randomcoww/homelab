
locals {
  domain_regex = "(?<hostname>(?<subdomain>[a-z0-9-*]+)\\.(?<domain>[a-z0-9.-]+))(?::(?<port>\\d+))?"
}

resource "random_bytes" "jwt-secret" {
  length = 256
}

resource "random_password" "storage-secret" {
  length  = 128
  special = false
}

locals {
  base_path = "/var/lib/lldap"
  extra_envs = merge(var.extra_configs, {
    LLDAP_LDAP_PORT                = 3890
    LLDAP_HTTP_PORT                = 17170
    LLDAP_LDAPS_OPTIONS__PORT      = var.service_port
    LLDAP_LDAPS_OPTIONS__CERT_FILE = "${local.base_path}/tls.crt"
    LLDAP_LDAPS_OPTIONS__KEY_FILE  = "${local.base_path}/tls.key"
    LLDAP_KEY_FILE                 = "${local.base_path}/private_key"
    LLDAP_JWT_SECRET               = random_bytes.jwt-secret.base64
    LLDAP_KEY_SEED                 = ""
    LLDAP_HTTP_HOST                = "0.0.0.0"
    LLDAP_LDAP_HOST                = "0.0.0.0"
    LLDAP_HTTP_URL                 = "https://${var.ingress_hostname}"
    LLDAP_LDAP_BASE_DN             = "dc=${join(",dc=", split(".", regex(local.domain_regex, var.service_hostname).domain))}"
  })
}

module "secret" {
  source    = "../../../modules/secret"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = merge({
    "storage-secret" = random_password.storage-secret.result
    }, {
    for k, v in local.extra_envs :
    tostring(k) => tostring(v)
  })
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
        name       = "ldaps"
        port       = local.extra_envs.LLDAP_LDAPS_OPTIONS__PORT
        protocol   = "TCP"
        targetPort = local.extra_envs.LLDAP_LDAPS_OPTIONS__PORT
      },
      {
        name       = "http"
        port       = local.extra_envs.LLDAP_HTTP_PORT
        protocol   = "TCP"
        targetPort = local.extra_envs.LLDAP_HTTP_PORT
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
            port = local.extra_envs.LLDAP_HTTP_PORT
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
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
    "secret.reloader.stakater.com/reload" = join(",", [
      "${var.name}-tls",
      "${var.name}-pg-app",
    ])
  }
  template_spec = {
    resources = {
      requests = {
        memory = "128Mi"
      }
      limits = {
        memory = "128Mi"
      }
    }
    containers = [
      {
        name  = var.name
        image = var.images.lldap
        args = [
          "run",
          "-c",
          "/dev/null",
        ]
        env = concat([
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
          ], [
          {
            name = "LLDAP_DATABASE_URL"
            valueFrom = {
              secretKeyRef = {
                name = "${var.name}-pg-app"
                key  = "uri"
              }
            }
          },
        ])
        volumeMounts = [
          {
            name      = "secret"
            mountPath = local.extra_envs.LLDAP_KEY_FILE
            subPath   = "storage-secret"
          },
          {
            name      = "lldap-cert"
            mountPath = local.extra_envs.LLDAP_LDAPS_OPTIONS__CERT_FILE
            subPath   = "tls.crt"
          },
          {
            name      = "lldap-cert"
            mountPath = local.extra_envs.LLDAP_LDAPS_OPTIONS__KEY_FILE
            subPath   = "tls.key"
          },
        ]
        ports = [
          {
            containerPort = local.extra_envs.LLDAP_HTTP_PORT
          },
          {
            containerPort = local.extra_envs.LLDAP_LDAPS_OPTIONS__PORT
          },
        ]
        livenessProbe = {
          exec = {
            command = [
              "/app/lldap",
              "healthcheck",
              "--config-file",
              "/data/lldap_config.toml",
            ]
          }
          initialDelaySeconds = 10
          timeoutSeconds      = 2
        }
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
        name = "lldap-cert"
        secret = {
          secretName = "${var.name}-tls"
        }
      },
    ]
  }
}