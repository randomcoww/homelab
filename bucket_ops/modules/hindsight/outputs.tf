output "manifests" {
  value = concat([
    module.cnpg-secret.manifest,
    module.httproute.manifest,
    ], [
    for _, m in [
      {
        apiVersion = "source.toolkit.fluxcd.io/v1"
        kind       = "OCIRepository"
        metadata = {
          name      = "hindsight"
          namespace = "ai"
        }
        spec = {
          interval = "15m"
          url      = "oci://ghcr.io/vectorize-io/charts/hindsight"
          ref = {
            tag = "0.9.2" # renovate: datasource=docker depName=ghcr.io/vectorize-io/charts/hindsight depType=helm_regex
          }
        }
      },
      {
        apiVersion = "helm.toolkit.fluxcd.io/v2"
        kind       = "HelmRelease"
        metadata = {
          name      = "hindsight"
          namespace = "ai"
        }
        spec = {
          interval = "15m"
          timeout  = "5m"
          chartRef = {
            kind      = "OCIRepository"
            name      = "hindsight"
            namespace = "ai"
          }
          releaseName = "hindsight"
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
            api = {
              replicaCount = 1
              service = {
                targetPort = var.service_port
              }
              env = merge({
                SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt"
              }, var.extra_envs)
              secrets = merge({
              }, var.extra_secrets)
              extraVolumeMounts = [
                {
                  name      = "pg-tls"
                  mountPath = local.client_tls_path
                },
                {
                  name      = "ca-trust-bundle"
                  mountPath = "/etc/ssl/certs/ca-certificates.crt"
                  readOnly  = true
                },
              ]
              extraVolumes = [
                {
                  name = "pg-tls"
                  secret = {
                    secretName  = "${var.name}-pg-client-tls"
                    defaultMode = 384
                  }
                },
                {
                  name = "ca-trust-bundle"
                  hostPath = {
                    path = "/etc/ssl/certs/ca-certificates.crt"
                    type = "File"
                  }
                },
              ]
            }
            worker = {
              enabled      = true
              replicaCount = 2
              # helm chart copies env and secrets from api
              extraVolumeMounts = [
                {
                  name      = "pg-tls"
                  mountPath = local.client_tls_path
                },
                {
                  name      = "ca-trust-bundle"
                  mountPath = "/etc/ssl/certs/ca-certificates.crt"
                  readOnly  = true
                },
              ]
              extraVolumes = [
                {
                  name = "pg-tls"
                  secret = {
                    secretName  = "${var.name}-pg-client-tls"
                    defaultMode = 384
                  }
                },
                {
                  name = "ca-trust-bundle"
                  hostPath = {
                    path = "/etc/ssl/certs/ca-certificates.crt"
                    type = "File"
                  }
                },
              ]
            }
            controlPlane = {
              enabled = true
              service = {
                targetPort = local.controlplane_port
              }
            }
            postgresql = {
              enabled = false
              external = {
                username = local.postgres_username
                host     = "${var.name}-pg-rw.${var.namespace}"
                port     = 5432
                database = join("&", ["${local.postgres_database}?sslmode=verify-full",
                  "sslrootcert=${local.client_tls_path}/ca.crt",
                  "sslcert=${local.client_tls_path}/tls.crt",
                  "sslkey=${local.client_tls_path}/tls.key",
                ])
                password = random_password.postgres-password.result
              }
            }
            metrics = {
              serviceMonitor = {
                enabled = true
              }
            }
          }
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
            size = "4Gi"
          }
          bootstrap = {
            initdb = {
              database = local.postgres_database
              owner    = local.postgres_username
              secret = {
                name = module.cnpg-secret.name
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
                    "0.8.6-18-trixie@sha256:06db9cf51210e9d70f26b569db31ae0b5289b9ef96bdb590deb45247349fcc58", # renovate: datasource=docker depName=ghcr.io/cloudnative-pg/pgvector
                  ])
                }
              },
            ]
          }
          resources = {
            requests = {
              memory = "256Mi"
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
          name      = "${var.name}-${local.postgres_database}"
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