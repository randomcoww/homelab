resource "minio_s3_object" "fluxcd-node-feature-discovery" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "node-feature-discovery"
            namespace = "kube-system"
          }
          spec = {
            interval = "15m"
            url      = "https://kubernetes-sigs.github.io/node-feature-discovery/charts"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "node-feature-discovery"
            namespace = "kube-system"
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "node-feature-discovery"
                version = "0.19.0" # renovate: datasource=helm depName=node-feature-discovery registryUrl=https://kubernetes-sigs.github.io/node-feature-discovery/charts
                sourceRef = {
                  kind = "HelmRepository"
                  name = "node-feature-discovery"
                }
                interval = "5m"
              }
            }
            releaseName = "node-feature-discovery"
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
              master = {
                replicaCount = 2
              }
              worker = {
                config = {
                  sources = {
                    custom = [
                      {
                        name = "hostapd-compat"
                        labels = {
                          hostapd-compat = true
                        }
                        matchFeatures = [
                          {
                            feature = "kernel.loadedmodule"
                            matchName = {
                              op = "InRegexp",
                              value = [
                                "^rtw8",
                                "^mt7",
                              ]
                            }
                          },
                        ]
                      },
                    ]
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
  object_name  = "node-feature-discovery/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}