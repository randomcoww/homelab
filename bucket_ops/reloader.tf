resource "minio_s3_object" "fluxcd-reloader" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "reloader"
            namespace = "kube-system"
          }
          spec = {
            interval = "15m"
            url      = "https://stakater.github.io/stakater-charts"
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
            chart = {
              spec = {
                chart   = "reloader"
                version = "2.2.16" # renovate: datasource=helm depName=reloader registryUrl=https://stakater.github.io/stakater-charts
                sourceRef = {
                  kind = "HelmRepository"
                  name = "reloader"
                }
                interval = "5m"
              }
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