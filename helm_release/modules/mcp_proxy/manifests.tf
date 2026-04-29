locals {
  proxy_config_file = "/var/lib/mcp-proxy/config.json"
  domain_regex      = "(?<hostname>(?<subdomain>[a-z0-9-*]+)\\.(?<domain>[a-z0-9.-]+))(?::(?<port>\\d+))?"

  ports = {
    service         = 8086
    kubernetes_mcp  = 8081
    prometheus_mcp  = 8082
    searxng_mcp     = 8083
    camofox_browser = 8084
    camofox_mcp     = 8085
    searxng_mcp     = 8087
  }

  manifests = concat([
    module.deployment.manifest,
    module.secret.manifest,
    module.service.manifest,
    module.httproute.manifest,
    ], [
    for _, m in [
      # kubernetes-mcp
      {
        apiVersion = "v1"
        kind       = "ServiceAccount"
        metadata = {
          name = var.name
          labels = {
            app     = var.name
            release = var.release
          }
        }
      },
      {
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
      },
      {
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
      },
    ] :
    yamlencode(m)
  ])
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
        searxng = {
          url           = "http://127.0.0.1:${local.ports.searxng_mcp}/mcp"
          name          = "searxng"
          transportType = "streamable-http"
          options = {
            toolFilter = {
              mode = "allow"
              list = [
                "searxng_web_search",
              ]
            }
          }
        }
        camofox = {
          url           = "http://127.0.0.1:${local.ports.camofox_mcp}/mcp"
          name          = "camofox"
          transportType = "streamable-http"
          options = {
            toolFilter = {
              mode = "allow"
              list = [
                "create_tab",
                "camofox_wait_for",
                "snapshot",
              ]
            }
          }
        }
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
    PROXY_HOST     = regex(local.domain_regex, var.scrape_proxy.server).hostname
    PROXY_PORT     = regex(local.domain_regex, var.scrape_proxy.server).port
    PROXY_USERNAME = var.scrape_proxy.username
    PROXY_PASSWORD = var.scrape_proxy.password
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
        port       = local.ports.service
        protocol   = "TCP"
        targetPort = local.ports.service
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
            port = local.ports.service
          },
        ]
      },
    ]
  }
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
        memory = "4Gi"
      }
      limits = {
        memory = "4Gi"
      }
    }
    initContainers = [
      # searxng
      {
        name          = "${var.name}-searxng-mcp"
        image         = var.images.searxng_mcp
        restartPolicy = "Always"
        env = [
          {
            name  = "MCP_HTTP_PORT"
            value = tostring(local.ports.searxng_mcp)
          },
          {
            name  = "SEARXNG_URL"
            value = "https://${var.searxng_endpoint}"
          },
        ]
        # TODO: add healthchecks
      },
      # camofox-mcp
      {
        name          = "${var.name}-camofox-browser"
        image         = var.images.camofox_browser
        restartPolicy = "Always"
        env = [
          {
            name  = "CAMOFOX_PORT"
            value = tostring(local.ports.camofox_browser)
          },
          {
            name  = "CAMOFOX_HEADLESS"
            value = "virtual"
          },
          {
            name = "PROXY_HOST"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = "PROXY_HOST"
              }
            }
          },
          {
            name = "PROXY_PORT"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = "PROXY_PORT"
              }
            }
          },
          {
            name = "PROXY_USERNAME"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = "PROXY_USERNAME"
              }
            }
          },
          {
            name = "PROXY_PASSWORD"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = "PROXY_PASSWORD"
              }
            }
          },
        ]
        volumeMounts = [
          {
            name      = "dev-shm"
            mountPath = "/dev/shm"
          },
        ]
        # TODO: add healthchecks
      },
      {
        name          = "${var.name}-camofox-mcp"
        image         = var.images.camofox_mcp
        restartPolicy = "Always"
        env = [
          {
            name  = "CAMOFOX_TRANSPORT"
            value = "http"
          },
          {
            name  = "CAMOFOX_URL"
            value = "http://127.0.0.1:${local.ports.camofox_browser}"
          },
          {
            name  = "CAMOFOX_HTTP_HOST"
            value = "127.0.0.1"
          },
          {
            name  = "CAMOFOX_HTTP_PORT"
            value = tostring(local.ports.camofox_mcp)
          },
        ]
        # TODO: add healthchecks
      },
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
        name = "dev-shm"
        emptyDir = {
          medium    = "Memory"
          sizeLimit = "2Gi"
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