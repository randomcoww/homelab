locals {
  victoria-metrics-mcp_name      = "${local.victoria-metrics_name}mcp"
  victoria-metrics-mcp_namespace = local.victoria-metrics_namespace
  victoria-metrics-mcp_port      = 8080
}

resource "minio_s3_object" "fluxcd-victoria-metrics-mcp" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = local.victoria-metrics-mcp_name
            namespace = local.victoria-metrics-mcp_namespace
          }
          spec = {
            interval = "15m"
            url      = "https://victoriametrics.github.io/helm-charts"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = local.victoria-metrics-mcp_name
            namespace = local.victoria-metrics-mcp_namespace
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "victoria-metrics-mcp"
                version = "0.3.0" # renovate: datasource=helm depName=victoria-metrics-mcp registryUrl=https://victoriametrics.github.io/helm-charts
                sourceRef = {
                  kind = "HelmRepository"
                  name = local.victoria-metrics-mcp_name
                }
                interval = "5m"
              }
            }
            releaseName = local.victoria-metrics-mcp_name
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
              vm = {
                type       = "cluster"
                entrypoint = "https://${local.httproutes.victoria-metrics.hostname}"
              }
              service = {
                port = local.victoria-metrics-mcp_port
              }
              resources = {
                requests = {
                  memory = "512Mi"
                }
                limits = {
                  memory = "1Gi"
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
  object_name  = "victoria-metrics-mcp/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}
