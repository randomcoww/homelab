resource "minio_s3_object" "fluxcd-trust-manager" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "OCIRepository"
          metadata = {
            name      = "trust-manager"
            namespace = local.services.cert-manager.namespace
          }
          spec = {
            interval = "15m"
            url      = "oci://quay.io/jetstack/charts/trust-manager"
            ref = {
              tag = "0.26.0" # renovate: datasource=docker depName=quay.io/jetstack/charts/trust-manager depType=helm_regex
            }
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
            chartRef = {
              kind      = "OCIRepository"
              name      = "trust-manager"
              namespace = local.services.cert-manager.namespace
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
