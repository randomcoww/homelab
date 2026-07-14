output "manifests" {
  value = concat([
    module.secret.manifest,
    module.ldap-client-tls.manifest,
    module.redis-client-tls.manifest,
    ], [
    for _, m in [
      # database
      {
        apiVersion = "postgresql.cnpg.io/v1"
        kind       = "Cluster"
        metadata = {
          name      = "${var.name}-pg"
          namespace = var.namespace
        }
        spec = {
          instances = 3
          storage = {
            size = "2Gi"
          }
          bootstrap = {
            initdb = {
              database = "authelia"
              owner    = "authelia"
            }
          }
          resources = {
            requests = {
              memory = "256Mi"
            }
          }
        }
      },

      # authelia helm
      {
        apiVersion = "source.toolkit.fluxcd.io/v1"
        kind       = "HelmRepository"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          interval = "15m"
          url      = "https://charts.authelia.com"
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
              chart   = "authelia"
              version = "0.11.6" # renovate: datasource=helm depName=authelia registryUrl=https://charts.authelia.com
              sourceRef = {
                kind = "HelmRepository"
                name = var.name
              }
              interval = "5m"
            }
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
          values = local.values
        }
      },
    ] :
    yamlencode(m)
  ])
}