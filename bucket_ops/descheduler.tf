resource "minio_s3_object" "fluxcd-descheduler" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "descheduler"
            namespace = "kube-system"
          }
          spec = {
            interval = "6h"
            url      = "https://kubernetes-sigs.github.io/descheduler"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "descheduler"
            namespace = "kube-system"
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "descheduler"
                version = "0.37.0" # renovate: datasource=helm depName=descheduler registryUrl=https://kubernetes-sigs.github.io/descheduler
                sourceRef = {
                  kind = "HelmRepository"
                  name = "descheduler"
                }
                interval = "6h"
              }
            }
            releaseName = "descheduler"
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
              timeZone = local.timezone
              deschedulerPolicy = {
                profiles = [
                  {
                    name = "custom"
                    pluginConfig = [
                      {
                        name = "DefaultEvictor"
                        args = {
                          podProtections = {
                            defaultDisabled = [
                              "PodsWithLocalStorage",
                            ]
                            extraEnabled = [
                              "PodsWithPVC",
                            ]
                          }
                        }
                      },
                      {
                        name = "LowNodeUtilization"
                        args = {
                          thresholds = {
                            memory = 60
                          }
                          targetThresholds = {
                            memory = 70
                          }
                        }
                      },
                      {
                        name = "RemovePodsViolatingNodeAffinity"
                        args = {
                          nodeAffinityType = [
                            "requiredDuringSchedulingIgnoredDuringExecution",
                          ]
                        }
                      },
                      {
                        name = "RemoveDuplicates"
                      },
                      {
                        name = "RemovePodsViolatingInterPodAntiAffinity"
                      },
                      {
                        name = "RemovePodsViolatingNodeTaints"
                      },
                      {
                        name = "RemovePodsViolatingTopologySpreadConstraint"
                        args = {
                          constraints = [
                            "DoNotSchedule",
                            "ScheduleAnyway",
                          ]
                        }
                      },
                    ]
                    plugins = {
                      balance = {
                        enabled = [
                          "LowNodeUtilization",
                          "RemoveDuplicates",
                          "RemovePodsViolatingTopologySpreadConstraint",
                        ]
                      }
                      deschedule = {
                        enabled = [
                          "RemovePodsViolatingNodeTaints",
                          "RemovePodsViolatingNodeAffinity",
                          "RemovePodsViolatingInterPodAntiAffinity",
                        ]
                      }
                    }
                  },
                ]
              }
              service = {
                enabled = true
              }
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
            name = "kube-system"
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
  object_name  = "descheduler/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}