
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
    "templates/serviceaccount.yaml" = yamlencode({
      apiVersion = "v1"
      kind       = "ServiceAccount"
      metadata = {
        name = var.name
        labels = {
          app     = var.name
          release = var.release
        }
      }
    })
    "templates/clusterrole.yaml" = yamlencode({
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "ClusterRole"
      metadata = {
        name = var.name
        labels = {
          app     = var.name
          release = var.release
        }
      }
      rules = [
        {
          apiGroups = ["*"]
          resources = ["*"]
          verbs     = ["list", "watch", "get"]
        },
      ]
    })
    "templates/clusterrolebinding.yaml" = yamlencode({
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "ClusterRoleBinding"
      metadata = {
        name = var.name
        labels = {
          app     = var.name
          release = var.release
        }
      }
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io"
        kind     = "ClusterRole"
        name     = var.name
      }
      subjects = [
        {
          kind      = "ServiceAccount"
          name      = var.name
          namespace = var.namespace
        },
      ]
    })
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
    serviceAccountName = var.name
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
        image = var.images.kubernetes_mcp
        ports = [
          {
            containerPort = local.mcp_port
          },
        ]
        args = [
          "--port",
          tostring(local.mcp_port),
          "--disable-multi-cluster",
          "--disable-destructive",
          "--sse-base-url",
          "https://${var.ingress_hostname}",
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
        name = "config"
        secret = {
          secretName = module.secret.name
        }
      },
    ]
  }
}