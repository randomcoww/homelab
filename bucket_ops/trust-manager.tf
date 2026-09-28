resource "minio_s3_object" "fluxcd-trust-manager" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "trust-manager"
            namespace = local.services.cert-manager.namespace
          }
          spec = {
            interval = "15m"
            url      = "https://charts.jetstack.io"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "trust-manager"
            namespace = local.services.cert-manager.namespace
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "trust-manager"
                version = "v0.25.0" # renovate: datasource=helm depName=trust-manager registryUrl=https://charts.jetstack.io
                sourceRef = {
                  kind = "HelmRepository"
                  name = "trust-manager"
                }
                interval = "5m"
              }
            }
            releaseName = "trust-manager"
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
              replicaCount = 1
              app = {
                trust = {
                  namespace = local.services.cert-manager.namespace
                }
                metrics = {
                  service = {
                    enabled = true
                    servicemonitor = {
                      enabled = true
                    }
                  }
                }
              }
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
  object_name  = "trust-manager/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}
