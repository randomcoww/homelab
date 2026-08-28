resource "minio_s3_object" "fluxcd-dragonfly-operator" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "OCIRepository"
          metadata = {
            name      = "dragonfly-operator"
            namespace = "dragonflydb"
          }
          spec = {
            interval = "15m"
            url      = "oci://ghcr.io/dragonflydb/dragonfly-operator/helm/dragonfly-operator"
            ref = {
              tag = "v1.6.1" # renovate: datasource=docker depName=ghcr.io/dragonflydb/dragonfly-operator/helm/dragonfly-operator depType=helm_regex
            }
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "dragonfly-operator"
            namespace = "dragonflydb"
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chartRef = {
              kind      = "OCIRepository"
              name      = "dragonfly-operator"
              namespace = "dragonflydb"
            }
            releaseName = "dragonfly-operator"
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
              serviceMonitor = {
                enabled = true
              }
              rbacProxy = {
                enabled = true
                resources = {
                  limits = {
                    memory = "192Mi"
                  }
                }
              }
            }
          }
        },

        # NS
        {
          apiVersion = "v1"
          kind       = "Namespace"
          metadata = {
            name = "dragonflydb"
            annotations = {
              "kustomize.toolkit.fluxcd.io/prune" = "disabled"
            }
          }
        },
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
  object_name  = "dragonfly-operator/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}
