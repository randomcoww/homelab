locals {
  proxy_config_file = "/var/lib/mcp-proxy/config.json"

  ports = {
    service        = 8086
    kubernetes_mcp = 8081
    prometheus_mcp = 8082
  }
}

module "secret" {
  source    = "../../../modules/secret"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    basename(local.proxy_config_file) = jsonencode({
      mcpProxy = {
        baseURL = "https://${var.ingress_hostname}"
        addr    = "0.0.0.0:${local.ports.service}"
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
        kubernetes = {
          url           = "http://127.0.0.1:${local.ports.kubernetes_mcp}/mcp"
          name          = "kubernetes"
          transportType = "streamable-http"
        }
        prometheus = {
          url           = "http://127.0.0.1:${local.ports.prometheus_mcp}/mcp"
          name          = "prometheus"
          transportType = "streamable-http"
        }
      }
    })
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
        name       = "mcp"
        port       = local.ports.service
        protocol   = "TCP"
        targetPort = local.ports.service
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
            port = local.ports.service
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
  }
  template_spec = {
    resources = {
      requests = {
        memory = "2Gi"
      }
      limits = {
        memory = "2Gi"
      }
    }
    initContainers = [
      # kubernetes-mcp
      {
        name          = "${var.name}-kubernetes-mcp"
        image         = var.images.kubernetes_mcp
        restartPolicy = "Always"
        args = [
          "--port",
          tostring(local.ports.kubernetes_mcp),
          "--disable-multi-cluster",
          "--stateless",
          "--cluster-provider",
          "in-cluster",
          "--toolsets",
          "core,helm",
          "--read-only",
        ]
        volumeMounts = [
          {
            name      = "service-account"
            mountPath = "/var/run/secrets/kubernetes.io/serviceaccount"
            readOnly  = true
          },
        ]
        livenessProbe = {
          httpGet = {
            port = local.ports.kubernetes_mcp
            path = "/healthz"
          }
          initialDelaySeconds = 10
          timeoutSeconds      = 2
        }
        readinessProbe = {
          httpGet = {
            port = local.ports.kubernetes_mcp
            path = "/healthz"
          }
        }
      },
      # prometheus-mcp
      {
        name          = "${var.name}-prometheus-mcp"
        image         = var.images.prometheus_mcp
        restartPolicy = "Always"
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
            value = "https://${var.prometheus_endpoint}"
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
            value = "127.0.0.1"
          },
          {
            name  = "PROMETHEUS_MCP_BIND_PORT"
            value = tostring(local.ports.prometheus_mcp)
          },
        ]
        volumeMounts = [
          {
            name      = "ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            readOnly  = true
          },
        ]
        # TODO: add healthchecks
      },
    ]
    containers = [
      {
        name  = var.name
        image = var.images.mcp_proxy
        args = [
          "--config",
          local.proxy_config_file,
        ]
        ports = [
          {
            containerPort = local.ports.service
          },
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.proxy_config_file
            subPath   = basename(local.proxy_config_file)
          },
        ]
        # TODO: add healthchecks
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
        hostPath = {
          path = "/etc/ssl/certs/ca-certificates.crt"
          type = "File"
        }
      },
      {
        name = "service-account"
        projected = {
          sources = [
            {
              serviceAccountToken = {
                path              = "token"
                expirationSeconds = 3600
              }
            },
            {
              downwardAPI = {
                items = [
                  {
                    path = "namespace"
                    fieldRef = {
                      fieldPath = "metadata.namespace"
                    }
                  },
                ]
              }
            },
            {
              configMap = {
                name = "kube-root-ca.crt"
                items = [
                  {
                    key  = "ca.crt"
                    path = "ca.crt"
                  },
                ]
              }
            },
          ]
        }
      },
    ]
  }
}