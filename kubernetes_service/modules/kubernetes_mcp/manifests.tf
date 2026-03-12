locals {
  mcp_port          = 8080
  proxy_port        = 8081
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
    "templates/service.yaml"    = module.service.manifest
    "templates/secret.yaml"     = module.secret.manifest
    "templates/httproute.yaml"  = module.httproute.manifest
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
  data = merge({
    basename(local.proxy_config_file) = jsonencode({
      mcpProxy = {
        baseURL = "https://${var.ingress_hostname}"
        addr    = "0.0.0.0:${local.proxy_port}"
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
        "/" = {
          url           = "http://127.0.0.1:${local.mcp_port}/mcp"
          transportType = "streamable-http"
        }
      }
    })
  })
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
        port       = local.proxy_port
        protocol   = "TCP"
        targetPort = local.proxy_port
      },
    ]
  }
}

module "httproute" {
  source  = "../../../modules/httproute"
  name    = var.name
  app     = var.name
  release = var.release
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
            port = local.proxy_port
          },
        ]
      }
    ]
  }
}

module "deployment" {
  source   = "../../../modules/deployment"
  name     = var.name
  app      = var.name
  release  = var.release
  replicas = var.replicas
  affinity = var.affinity
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
        name  = "${var.name}-proxy"
        image = var.images.mcp_proxy
        args = [
          "--config",
          local.proxy_config_file,
        ]
        ports = [
          {
            containerPort = local.proxy_port
          },
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.proxy_config_file
            subPath   = basename(local.proxy_config_file)
          },
        ]
      },
      {
        name  = var.name
        image = var.images.kubernetes_mcp
        args = [
          "--port",
          tostring(local.mcp_port),
          "--disable-multi-cluster",
          "--stateless",
          "--sse-base-url",
          "https://${var.ingress_hostname}",
        ]
        livenessProbe = {
          httpGet = {
            port = local.mcp_port
            path = "/healthz"
          }
          initialDelaySeconds = 10
          timeoutSeconds      = 2
        }
        readinessProbe = {
          httpGet = {
            port = local.mcp_port
            path = "/healthz"
          }
        }
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