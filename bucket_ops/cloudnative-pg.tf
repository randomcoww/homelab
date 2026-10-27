resource "minio_s3_object" "fluxcd-cloudnative-pg" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "cloudnative-pg"
            namespace = "cnpg-system"
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              kind = "OCIRepository"
              spec = {
                interval = "6h"
                url      = "oci://ghcr.io/cloudnative-pg/charts/cloudnative-pg"
                ref = {
                  tag = "0.29.1" # renovate: datasource=docker depName=ghcr.io/cloudnative-pg/charts/cloudnative-pg depType=helm_regex
                }
                layerSelector = {
                  mediaType = "application/vnd.cncf.helm.chart.content.v1.tar+gzip"
                  operation = "copy"
                }
              }
            }
            releaseName = "cloudnative-pg"
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
              config = {
                data = {
                  KUBERNETES_CLUSTER_DOMAIN = local.domains.kubernetes
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
            name = "cnpg-system"
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
  object_name  = "cloudnative-pg/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}