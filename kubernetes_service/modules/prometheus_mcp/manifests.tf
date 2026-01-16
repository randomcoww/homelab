
locals {
  mcp_port = 8080
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.release
  manifests = {
    "templates/deployment.yaml" = module.deployment.manifest
    "templates/service.yaml"    = module.service.manifest
    "templates/ingress.yaml"    = module.ingress.manifest
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
        port       = local.mcp_port
        protocol   = "TCP"
        targetPort = local.mcp_port
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
          port    = local.mcp_port
          path    = "/"
        },
      ]
    },
  ]
}

module "deployment" {
  source   = "../../../modules/deployment"
  name     = var.name
  app      = var.name
  release  = var.release
  replicas = var.replicas
  affinity = var.affinity
  template_spec = {
    resources = {
      requests = {
        memory = "1Gi"
      }
      limits = {
        memory = "1Gi"
      }
    }
    containers = [
      {
        name  = var.name
        image = var.images.prometheus_mcp
        ports = [
          {
            containerPort = local.mcp_port
          },
        ]
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
    ]
    volumes = [
      {
        name = "ca-trust-bundle"
        hostPath = {
          path = "/etc/ssl/certs/ca-certificates.crt"
          type = "File"
        }
      },
    ]
  }
}