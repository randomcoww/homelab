
locals {
  mcp_proxy_port = 9090
  config_file    = "/config/config.json"
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
    "config.json" = jsonencode(merge(var.config, {
      mcpProxy = merge(lookup(var.config, "mcpProxy", {}), {
        baseURL = "https://${var.service_hostname}",
        addr    = ":${local.mcp_proxy_port}",
        name    = var.name,
      }),
    }))
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
        name       = "mcp-proxy"
        port       = local.mcp_proxy_port
        protocol   = "TCP"
        targetPort = local.mcp_proxy_port
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
      host = var.service_hostname
      paths = [
        {
          service = module.service.name
          port    = local.mcp_proxy_port
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
    containers = [
      {
        name  = var.name
        image = var.images.mcp_proxy
        args = [
          "--config",
          local.config_file,
        ]
        ports = [
          {
            containerPort = local.mcp_proxy_port
          },
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.config_file
            subPath   = "config.json"
          },
          {
            name      = "ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            subPath   = "ca.crt"
            readOnly  = true
          },
        ]
        # TODO: add health checks
      },
    ]
    volumes = [
      {
        name = "config"
        secret = {
          secretName = module.secret.name
        }
      },
      {
        name = "ca-trust-bundle"
        configMap = {
          name = var.ca_bundle_configmap
        }
      },
    ]
  }
}