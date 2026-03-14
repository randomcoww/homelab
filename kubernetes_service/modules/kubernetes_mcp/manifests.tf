locals {
  mcp_port          = 8080
  nginx_port        = 8081
  proxy_config_file = "/var/lib/mcp-proxy/config.json"
  config_path       = "/etc/kubernetes-mcp-server/config.d"
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
    "templates/configmap.yaml"  = module.configmap.manifest
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

# TODO: issues with aud and client_id
# I0314 05:53:10.772722       1 authorization.go:91] "Authentication failed - JWT validation error: POST / from 10.244.3.4:54144, error: JWT token validation error: go-jose/go-jose/jwt: validation failed, invalid audience claim (aud)"
# I0314 07:27:23.099809       1 authorization.go:91] "Authentication failed - JWT validation error: POST /mcp from 10.244.0.4:57372, error: OIDC token validation error: oidc: invalid configuration, clientID must be provided or SkipClientIDCheck must be set"
module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = merge({
    "oauth.toml" = <<-EOF
    require_oauth = true
    oauth_audience = "${var.oauth_client_id}"
    oauth_scopes = ["${join("\",\"", var.oauth_scopes)}"]
    disable_dynamic_client_registration = false
    authorization_url = "${var.oauth_authorization_url}"
    server_url = "https://${var.ingress_hostname}"
    EOF
  }, var.extra_configs)
}

# TODO: remove if implementation changes
# MCP tried to fetch .well-known/oauth-protected-resource from authelia which it does not serve
module "configmap" {
  source  = "../../../modules/configmap"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    "nginx-oauth-protected-resource.conf" = <<-EOF
    server {
      listen ${local.nginx_port};

      location = /.well-known/oauth-protected-resource {
        default_type application/json;
        return 200 '{
          "resource": "https://${var.ingress_hostname}",
          "authorization_servers": ["${var.oauth_authorization_url}"],
          "scopes_supported": ["${join("\",\"", var.oauth_scopes)}"]
          "bearer_methods_supported": ["header"]
        }';
        add_header Access-Control-Allow-Origin "*" always;
        add_header Access-Control-Allow-Methods "GET, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Content-Type, Authorization" always;
      }
    }
    EOF
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
      {
        name       = "nginx"
        port       = local.nginx_port
        protocol   = "TCP"
        targetPort = local.nginx_port
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
              value = "/.well-known/oauth-protected-resource"
            }
          },
        ]
        backendRefs = [
          {
            name = module.service.name
            port = local.nginx_port
          },
        ]
      },
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
            port = local.mcp_port
          },
        ]
      },
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
    "checksum/secret"    = sha256(module.secret.manifest)
    "checksum/configmap" = sha256(module.configmap.manifest)
  }
  template_spec = {
    automountServiceAccountToken = true
    serviceAccountName           = var.name
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
        args = [
          "--port",
          tostring(local.mcp_port),
          "--disable-multi-cluster",
          "--stateless",
          "--cluster-provider",
          "in-cluster",
          "--sse-base-url",
          "https://${var.ingress_hostname}",
          "--config-dir",
          local.config_path,
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.config_path
          },
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
      {
        name          = "${var.name}-nginx"
        image         = var.images.nginx
        restartPolicy = "Always"
        ports = [
          {
            containerPort = local.nginx_port
          },
        ]
        volumeMounts = [
          {
            name      = "nginx-config"
            mountPath = "/etc/nginx/conf.d/default.conf"
            subPath   = "nginx-oauth-protected-resource.conf"
          },
        ]
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
        name = "nginx-config"
        configMap = {
          name = module.configmap.name
        }
      },
    ]
  }
}