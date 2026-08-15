resource "minio_s3_object" "fluxcd-juicefs-csi-driver" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "juicefs-csi-driver"
            namespace = "juicefs"
          }
          spec = {
            interval = "15m"
            url      = "https://juicedata.github.io/charts"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "juicefs-csi-driver"
            namespace = "juicefs"
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "juicefs-csi-driver"
                version = "0.32.3" # renovate: datasource=helm depName=juicefs-csi-driver registryUrl=https://juicedata.github.io/charts
                sourceRef = {
                  kind = "HelmRepository"
                  name = "juicefs-csi-driver"
                }
                interval = "5m"
              }
            }
            releaseName = "juicefs-csi-driver"
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
              kubeletDir = local.kubernetes.kubelet_root_path
              dashboard = {
                enabled = false
              }
              globalConfig = {
                enabled = true
                mountPodPatch = [
                  {
                    mountOptions = [
                      "no-syslog",
                      "atime-mode=noatime",
                      "backup-meta=0",
                      "no-usage-report=true",
                    ]
                  },
                  {
                    ceMountImage = join(":", [
                      "reg.cluster.internal/randomcoww/juicefs",
                      "ce-v1.4.1.1786367431@sha256:6fd4e50823823ca71546920cbafb7c5b566bf4626227e5884db76672d10d872d", # renovate: datasource=docker depName=reg.cluster.internal/randomcoww/juicefs
                    ])
                  },
                  {
                    readinessProbe = {
                      exec = {
                        command = [
                          "stat",
                          "$${MOUNT_POINT}/$${SUB_PATH}",
                        ]
                      }
                      failureThreshold    = 3
                      initialDelaySeconds = 10
                      periodSeconds       = 5
                      successThreshold    = 1
                    }
                  },
                  {
                    resources = {
                      requests = {
                        memory = "256Mi"
                      }
                      limits = {
                        memory = "512Mi"
                      }
                    }
                  },
                ]
              }
            }
          }
        },

        # NS
        {
          apiVersion = "v1"
          kind       = "Namespace"
          metadata = {
            name = "juicefs"
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
  object_name  = "juicefs-csi-driver/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}