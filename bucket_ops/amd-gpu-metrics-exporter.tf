resource "minio_s3_object" "fluxcd-amd-gpu-metrics-exporter" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        # GPU metrics exporter
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "amd-gpu-metrics-exporter"
            namespace = "kube-amd-gpu"
          }
          spec = {
            interval = "15m"
            url      = "https://rocm.github.io/device-metrics-exporter"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "amd-gpu-metrics-exporter"
            namespace = "kube-amd-gpu"
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "device-metrics-exporter-charts"
                version = "v1.5.1" # renovate: datasource=helm depName=device-metrics-exporter-charts registryUrl=https://rocm.github.io/device-metrics-exporter
                sourceRef = {
                  kind = "HelmRepository"
                  name = "amd-gpu-metrics-exporter"
                }
                interval = "5m"
              }
            }
            releaseName = "amd-gpu-metrics-exporter"
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
            }
          }
        },

        # NS
        {
          apiVersion = "v1"
          kind       = "Namespace"
          metadata = {
            name = "kube-amd-gpu"
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
  object_name  = "amd-gpu-metrics-exporter/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}