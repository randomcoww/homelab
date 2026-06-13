locals {
  tls_path = "/etc/kubernetes-mcp-server"
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

module "deployment" {
  source = "../../../modules/deployment"

  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  affinity  = var.affinity
  replicas  = var.replicas
  annotations = {
    "checksum/secret" = sha256(module.tls.manifest)
  }
  template_spec = {
    serviceAccountName = var.name
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
        name  = "${var.name}-kubernetes-mcp"
        image = var.images.kubernetes_mcp
        args = [
          "--port",
          tostring(var.service_port),
          "--stateless",
          "--cluster-provider",
          "in-cluster",
          "--tls-cert",
          "${local.tls_path}/tls.crt",
          "--tls-key",
          "${local.tls_path}/tls.key",
          "--require-tls",
        ]
        volumeMounts = [
          {
            name      = "tls"
            mountPath = local.tls_path
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
          secretName = module.tls.name
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