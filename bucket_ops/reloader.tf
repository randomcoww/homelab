resource "minio_s3_object" "fluxcd-reloader" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "OCIRepository"
          metadata = {
            name      = "reloader"
            namespace = "kube-system"
          }
          spec = {
            interval = "6h"
            url      = "oci://ghcr.io/stakater/charts/reloader"
            ref = {
              tag = "2.2.19" # renovate: datasource=docker depName=ghcr.io/stakater/charts/reloader depType=helm_regex
            }
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "reloader"
            namespace = "kube-system"
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chartRef = {
              kind      = "OCIRepository"
              name      = "reloader"
              namespace = "kube-system"
            }
            releaseName = "reloader"
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
              reloader = {
                enableHA         = true
                reloadOnCreate   = true
                syncAfterRestart = true
                logLevel         = "debug"
                deployment = {
                  replicas = 2
                  resources = {
                    requests = {
                      memory = "128Mi"
                    }
                    limits = {
                      memory = "128Mi"
                    }
                  }
                }
                podMonitor = {
                  enabled = true
                }
                podDisruptionBudget = {
                  enabled      = true
                  minAvailable = 1
                }
              }
            }
          }
        }
      ] :
      yamlencode(m)
    ])
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "reloader/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}