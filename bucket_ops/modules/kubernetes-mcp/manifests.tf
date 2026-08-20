locals {
  config_path = "/etc/kubernetes-mcp-server/config.toml"
  tls_path    = "/etc/kubernetes-mcp-server"
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
        port       = var.service_port
        protocol   = "TCP"
        targetPort = var.service_port
      },
    ]
  }
}

module "configmap" {
  source    = "../../../modules/configmap"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    basename(local.config_path) = <<-EOF
    port = "${var.service_port}"
    list_output = "yaml"

    cluster_provider_strategy = "in-cluster"
    log_level = 2
    read_only = true
    toolsets = ["core", "helm"]
    require_tls = true
    tls_cert = "${local.tls_path}/tls.crt"
    tls_key = "${local.tls_path}/tls.key"

    [[denied_resources]]
    group = ""
    version = "v1"
    kind = "Secret"
    EOF
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
    "checksum/configmap"                  = sha256(module.configmap.manifest)
    "secret.reloader.stakater.com/reload" = "${var.name}-tls"
  })
  template_spec = {
    serviceAccountName = var.name
    resources = {
      requests = {
        memory = "128Mi"
      }
      limits = {
        memory = "384Mi"
      }
    }
    containers = [
      {
        name  = "${var.name}-kubernetes-mcp"
        image = "${var.images.kubernetes-mcp.repository}:${var.images.kubernetes-mcp.tag}"
        args = [
          "--config",
          local.config_path,
        ]
        volumeMounts = [
          {
            name      = "tls"
            mountPath = "${local.tls_path}/tls.crt"
            subPath   = "tls.crt"
          },
          {
            name      = "tls"
            mountPath = "${local.tls_path}/tls.key"
            subPath   = "tls.key"
          },
          {
            name      = "config"
            mountPath = local.config_path
            subPath   = basename(local.config_path)
          },
          {
            name      = "service-account"
            mountPath = "/var/run/secrets/kubernetes.io/serviceaccount"
            readOnly  = true
          },
        ]
        livenessProbe = {
          httpGet = {
            scheme = "HTTPS"
            port   = var.service_port
            path   = "/healthz"
          }
          initialDelaySeconds = 10
          timeoutSeconds      = 2
        }
        readinessProbe = {
          httpGet = {
            scheme = "HTTPS"
            port   = var.service_port
            path   = "/healthz"
          }
        }
      },
    ]
    volumes = [
      {
        name = "tls"
        secret = {
          secretName = "${var.name}-tls"
        }
      },
      {
        name = "config"
        configMap = {
          name = module.configmap.name
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