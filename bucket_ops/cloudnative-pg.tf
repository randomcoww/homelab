resource "minio_s3_object" "fluxcd-cloudnative-pg" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "cloudnative-pg"
            namespace = "cnpg-system"
          }
          spec = {
            interval = "15m"
            url      = "https://cloudnative-pg.github.io/charts"
          }
        },
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
              spec = {
                chart   = "cloudnative-pg"
                version = "0.29.0" # renovate: datasource=helm depName=cloudnative-pg registryUrl=https://cloudnative-pg.github.io/charts
                sourceRef = {
                  kind = "HelmRepository"
                  name = "cloudnative-pg"
                }
                interval = "5m"
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