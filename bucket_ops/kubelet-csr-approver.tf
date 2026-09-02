resource "minio_s3_object" "fluxcd-kubelet-csr-approver" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "kubelet-csr-approver"
            namespace = "kube-system"
          }
          spec = {
            interval = "15m"
            url      = "https://postfinance.github.io/kubelet-csr-approver"
          }
        },
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
              spec = {
                chart   = "kubelet-csr-approver"
                version = "1.2.15" # renovate: datasource=helm depName=kubelet-csr-approver registryUrl=https://postfinance.github.io/kubelet-csr-approver
                sourceRef = {
                  kind = "HelmRepository"
                  name = "kubelet-csr-approver"
                }
                interval = "5m"
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