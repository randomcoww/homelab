output "manifests" {
  value = concat([
    # runner resources in arc-runners
    module.user-secret.manifest,
    module.workflow-config.manifest,

    ], [
    for _, m in [
      {
        apiVersion = "source.toolkit.fluxcd.io/v1"
        kind       = "OCIRepository"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          interval = "15m"
          url      = "oci://ghcr.io/vectorize-io/charts/hindsight"
          ref = {
            tag = "0.8.5" # renovate: datasource=docker depName=ghcr.io/vectorize-io/charts/hindsight depType=helm_regex
          }
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
          chartRef = {
            kind      = "OCIRepository"
            name      = var.name
            namespace = var.namespace
          }
          releaseName = var.name
          install = {
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
              enabled      = true
              replicaCount = 2
            }
            worker = {
              enabled      = true
              replicaCount = 2
            }
            postgresql = {
              enabled = false
              external = {
                host     = "${var.name}-pg-rw.${var.namespace}"
                port     = 5432
                database = local.postgres_database
                username = local.postgres_username
              }
            }

            ingress = {
              enabled = true

            }
          }
        }
      },

      # database
      {
        apiVersion = "postgresql.cnpg.io/v1"
        kind       = "Cluster"
        metadata = {
          name      = "${var.name}-pg"
          namespace = var.namespace
          labels = {
            "cnpg.io/reload" = "true"
          }
        }
        spec = {
          instances = 3
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
          resources = {
            requests = {
              memory = "256Mi"
            }
          }
        }
      },
    ] :
    yamlencode(m)
  ])
}