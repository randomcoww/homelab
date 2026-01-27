locals {
  mcp_port          = 8080
  service_port      = 8081
  proxy_config_file = "/var/lib/mcp-proxy/config.json"
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.release
  manifests = {
    "templates/deployment.yaml" = module.deployment.manifest
    "templates/secret.yaml"     = module.secret.manifest
    "templates/service.yaml"    = module.service.manifest
    "templates/ingress.yaml"    = module.ingress.manifest
  }
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    basename(local.proxy_config_file) = jsonencode({
      mcpProxy = {
        baseURL = "https://${var.ingress_hostname}"
        addr    = "0.0.0.0:${local.service_port}"
        name    = var.name
        type    = "streamable-http"
        options = {
          panicIfInvalid = true
          logEnabled     = true
          authTokens = [
            var.auth_token,
          ]
        }
      }
      mcpServers = {
        "${var.name}" = {
          url           = "http://127.0.0.1:${local.mcp_port}/mcp"
          transportType = "streamable-http"
        }
      }
    })
  }
}

module "service" {
  source  = "../../../modules/service"
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = "mcp"
        port       = local.service_port
        protocol   = "TCP"
        targetPort = local.service_port
      },
    ]
  }
}

module "ingress" {
  source             = "../../../modules/ingress"
  name               = var.name
  app                = var.name
  release            = var.release
  ingress_class_name = var.ingress_class_name
  annotations        = var.nginx_ingress_annotations
  rules = [
    {
      host = var.ingress_hostname
      paths = [
        {
          service = module.service.name
          port    = local.service_port
          path    = "/"
        },
      ]
    },
  ]
}

module "deployment" {
  source = "../../../modules/deployment"

  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = var.replicas
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  template_spec = {
    resources = {
      requests = {
        memory = "256Mi"
      }
      limits = {
        memory = "256Mi"
      }
    }
    containers = [
      {
        name  = var.name
        image = var.images.prometheus_mcp
        env = [
          {
            name  = "SSL_CERT_FILE"
            value = "/etc/ssl/certs/ca-certificates.crt"
          },
          {
            name  = "REQUESTS_CA_BUNDLE"
            value = "/etc/ssl/certs/ca-certificates.crt"
          },
          {
            name  = "PROMETHEUS_URL"
            value = var.prometheus_url
          },
          {
            name  = "PROMETHEUS_URL_SSL_VERIFY"
            value = "true"
          },
          {
            name  = "PROMETHEUS_MCP_SERVER_TRANSPORT"
            value = "http"
          },
          {
            name  = "PROMETHEUS_MCP_BIND_HOST"
            value = "0.0.0.0"
          },
          {
            name  = "PROMETHEUS_MCP_BIND_PORT"
            value = tostring(local.mcp_port)
          },
        ]
        volumeMounts = [
          {
            name      = "ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            readOnly  = true
          },
        ]
        # TODO: add health checks
      },
      {
        name  = "${var.name}-proxy"
        image = var.images.mcp_proxy
        args = [
          "--config",
          local.proxy_config_file,
        ]
        ports = [
          {
            containerPort = local.service_port
          },
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.proxy_config_file
            subPath   = basename(local.proxy_config_file)
          },
        ]
        # TODO: add health checks
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
          secretName = module.secret.name
        }
      },
    ]
  }
}