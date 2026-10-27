resource "minio_s3_object" "fluxcd-kubelet-csr-approver" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "kubelet-csr-approver"
            namespace = "kube-system"
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              kind = "OCIRepository"
              spec = {
                interval = "6h"
                url      = "oci://ghcr.io/postfinance/charts/kubelet-csr-approver"
                ref = {
                  tag = "1.2.15" # renovate: datasource=docker depName=ghcr.io/postfinance/charts/kubelet-csr-approver depType=helm_regex
                }
              }
            }
            releaseName = "kubelet-csr-approver"
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
              global = {
                clusterDomain = local.domains.kubernetes
              }
              providerRegex       = "^k-\\d+$"
              bypassDnsResolution = true
              bypassHostnameCheck = true
              providerIpPrefixes = [
                local.networks.service.prefix,
              ]
              metrics = {
                enable = true
                serviceMonitor = {
                  enabled = true
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
  object_name  = "kubelet-csr-approver/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}