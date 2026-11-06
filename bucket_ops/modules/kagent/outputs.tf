
output "manifests" {
  value = concat([
    module.oidc-secret.manifest,
    module.redis-secret.manifest,
    module.postgres-secret.manifest,
    module.openai-secret.manifest,
    ], [
    for _, m in [
      # not working with OCIRepository and tag
      {
        apiVersion = "source.toolkit.fluxcd.io/v1"
        kind       = "HelmRepository"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          type     = "oci"
          interval = "15m"
          url      = "oci://ghcr.io/kagent-dev/kagent/helm"
        }
      },
      {
        apiVersion = "helm.toolkit.fluxcd.io/v2"
        kind       = "HelmRelease"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          interval = "15m"
          timeout  = "5m"
          chart = {
            spec = {
              chart = "kagent"
              sourceRef = {
                kind = "HelmRepository"
                name = var.name
              }
              version = "0.10.6" # renovate: datasource=docker depName=ghcr.io/kagent-dev/kagent/helm/kagent depType=helm_regex
            }
          }
          releaseName = var.name
          install = {
            createNamespace = true
            remediation = {
              retries = -1
            }
          }
          upgrade = {
            remediation = {
              retries = -1
            }
          }
          test = {
            enable = false
          }
          values = local.values
        }
      },

      # tools server
      {
        apiVersion = "source.toolkit.fluxcd.io/v1"
        kind       = "HelmRepository"
        metadata = {
          name      = "${var.name}-tools"
          namespace = var.namespace
        }
        spec = {
          type     = "oci"
          interval = "15m"
          url      = "oci://ghcr.io/kagent-dev/tools/helm"
        }
      },
      {
        apiVersion = "helm.toolkit.fluxcd.io/v2"
        kind       = "HelmRelease"
        metadata = {
          name      = "${var.name}-tools"
          namespace = var.namespace
        }
        spec = {
          interval = "15m"
          timeout  = "5m"
          chart = {
            spec = {
              chart = "kagent-tools"
              sourceRef = {
                kind = "HelmRepository"
                name = "${var.name}-tools"
              }
              version = "0.3.1" # renovate: datasource=docker depName=ghcr.io/kagent-dev/tools/helm/kagent-tools depType=helm_regex
            }
          }
          releaseName = "${var.name}-tools"
          install = {
            createNamespace = true
            remediation = {
              retries = -1
            }
          }
          upgrade = {
            remediation = {
              retries = -1
            }
          }
          test = {
            enable = false
          }
          values = {
            tools = {
              metrics = {
                port = 8085
                servicemonitor = {
                  enabled = true
                }
              }
            }
            service = {
              ports = {
                tools = {
                  port = local.tools_port
                  # targetPort = local.tools_port
                }
              }
            }
          }
        }
      },
      # create kagent-tools here to set custom timeout
      {
        apiVersion = "kagent.dev/v1alpha2"
        kind       = "RemoteMCPServer"
        metadata = {
          name      = "${var.name}-tool-server"
          namespace = var.namespace
        }
        spec = {
          url            = "http://${var.name}-tools.${var.namespace}:${local.tools_port}/mcp"
          protocol       = "STREAMABLE_HTTP"
          timeout        = "60m"
          sseReadTimeout = "60m"
          description    = "Official KAgent tool server"
        }
      },

      # postgres
      {
        apiVersion = "cert-manager.io/v1"
        kind       = "Certificate"
        metadata = {
          name      = "${var.name}-pg-tls"
          namespace = var.namespace
        }
        spec = {
          secretName = "${var.name}-pg-tls"
          secretTemplate = {
            labels = {
              "cnpg.io/reload" = ""
            }
          }
          isCA = false
          privateKey = {
            algorithm = "ECDSA"
            size      = 521
          }
          commonName = var.name
          usages = [
            "server auth",
          ]
          dnsNames = [
            "${var.name}-pg-rw",
            "${var.name}-pg-rw.${var.namespace}",
            "${var.name}-pg-r",
            "${var.name}-pg-r.${var.namespace}",
            "${var.name}-pg-ro",
            "${var.name}-pg-ro.${var.namespace}",
          ]
          issuerRef = {
            name = var.ca_issuer_name
            kind = "ClusterIssuer"
          }
        }
      },
      {
        apiVersion = "cert-manager.io/v1"
        kind       = "Certificate"
        metadata = {
          name      = "${var.name}-pg-rep-client-tls"
          namespace = var.namespace
        }
        spec = {
          secretName = "${var.name}-pg-rep-client-tls"
          secretTemplate = {
            labels = {
              "cnpg.io/reload" = ""
            }
          }
          isCA = false
          privateKey = {
            algorithm = "ECDSA"
            size      = 521
          }
          commonName = "streaming_replica" # required user name for replication client
          usages = [
            "client auth",
          ]
          issuerRef = {
            name = var.ca_issuer_name
            kind = "ClusterIssuer"
          }
        }
      },
      {
        apiVersion = "postgresql.cnpg.io/v1"
        kind       = "Cluster"
        metadata = {
          name      = "${var.name}-pg"
          namespace = var.namespace
        }
        spec = {
          instances = 2
          certificates = {
            serverTLSSecret      = "${var.name}-pg-tls"
            serverCASecret       = "${var.name}-pg-tls"
            clientCASecret       = "${var.name}-pg-rep-client-tls"
            replicationTLSSecret = "${var.name}-pg-rep-client-tls"
          }
          storage = {
            size = "2Gi"
          }
          bootstrap = {
            initdb = {
              database = local.postgres_database
              owner    = local.postgres_username
              secret = {
                name = module.postgres-secret.name
              }
            }
          }
          postgresql = {
            extensions = [
              {
                name = "pgvector"
                image = {
                  reference = join(":", [
                    "ghcr.io/cloudnative-pg/pgvector",
                    "0.8.7-18-trixie@sha256:36dd07720447813c0659c6d8a961e1bc79a4324c6d6de46cd57f6201b70db53a", # renovate: datasource=docker depName=ghcr.io/cloudnative-pg/pgvector
                  ])
                }
              },
            ]
          }
          resources = {
            requests = {
              memory = "128Mi"
            }
            limits = {
              memory = "256Mi"
            }
          }
        }
      },
      {
        apiVersion = "postgresql.cnpg.io/v1"
        kind       = "Database"
        metadata = {
          name      = "${var.name}-pg-${local.postgres_database}"
          namespace = var.namespace
        }
        spec = {
          name  = local.postgres_database
          owner = local.postgres_username
          cluster = {
            name = "${var.name}-pg"
          }
          extensions = [
            {
              name = "vector"
            },
          ]
        }
      },
      {
        apiVersion = "monitoring.coreos.com/v1"
        kind       = "PodMonitor"
        metadata = {
          name      = "${var.name}-pg"
          namespace = var.namespace
        }
        spec = {
          selector = {
            matchLabels = {
              "cnpg.io/cluster" = "${var.name}-pg"
            }
          }
          podMetricsEndpoints = [
            {
              port = "metrics"
            },
          ]
        }
      },

      # redis
      {
        apiVersion = "cert-manager.io/v1"
        kind       = "Certificate"
        metadata = {
          name      = "${var.name}-redis-tls"
          namespace = var.namespace
        }
        spec = {
          secretName = "${var.name}-redis-tls"
          isCA       = false
          privateKey = {
            algorithm = "ECDSA"
            size      = 521
          }
          commonName = "${var.name}-redis"
          usages = [
            "key encipherment",
            "digital signature",
          ]
          dnsNames = [
            "${var.name}-redis.${var.namespace}",
          ]
          issuerRef = {
            name = var.ca_issuer_name
            kind = "ClusterIssuer"
          }
        }
      },
      {
        apiVersion = "dragonflydb.io/v1alpha1"
        kind       = "Dragonfly"
        metadata = {
          name      = "${var.name}-redis"
          namespace = var.namespace
        }
        spec = {
          replicas = 2
          annotations = {
            "secret.reloader.stakater.com/reload" = "${var.name}-redis-tls"
          }
          resources = {
            requests = {
              memory = "128Mi"
            }
          }
          authentication = {
            passwordFromSecret = {
              name = module.redis-secret.name
              key  = "redis-password"
            }
          }
          tlsSecretRef = {
            name      = "${var.name}-redis-tls"
            namespace = var.namespace
          }
        }
      },

      # postgres client cert
      {
        apiVersion = "cert-manager.io/v1"
        kind       = "Certificate"
        metadata = {
          name      = "${var.name}-pg-client-tls"
          namespace = var.namespace
        }
        spec = {
          secretName = "${var.name}-pg-client-tls"
          isCA       = false
          privateKey = {
            algorithm = "ECDSA"
            size      = 521
          }
          commonName = var.name
          usages = [
            "client auth",
          ]
          issuerRef = {
            name = var.ca_issuer_name
            kind = "ClusterIssuer"
          }
        }
      },

      # NS
      {
        apiVersion = "v1"
        kind       = "Namespace"
        metadata = {
          name = var.namespace
          annotations = {
            "kustomize.toolkit.fluxcd.io/prune" = "disabled"
          }
        }
      },
    ] :
    yamlencode(m)
  ])
}