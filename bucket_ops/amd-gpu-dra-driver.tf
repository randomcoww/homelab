resource "minio_s3_object" "fluxcd-amd-gpu-dra-driver" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        # DRA driver
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "amd-gpu-dra-driver"
            namespace = "kube-amd-gpu"
          }
          spec = {
            interval = "15m"
            url      = "https://rocm.github.io/k8s-gpu-dra-driver"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "amd-gpu-dra-driver"
            namespace = "kube-amd-gpu"
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "k8s-gpu-dra-driver"
                version = "v1.0.1" # renovate: datasource=helm depName=k8s-gpu-dra-driver registryUrl=https://rocm.github.io/k8s-gpu-dra-driver
                sourceRef = {
                  kind = "HelmRepository"
                  name = "amd-gpu-dra-driver"
                }
                interval = "5m"
              }
            }
            releaseName = "amd-gpu-dra-driver"
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
  object_name  = "amd-gpu-dra-driver/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}