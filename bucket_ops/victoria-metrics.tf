resource "minio_s3_object" "fluxcd-victoria-metrics" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = local.endpoints.victoria-metrics.name
            namespace = local.endpoints.victoria-metrics.namespace
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
            name      = local.endpoints.victoria-metrics.name
            namespace = local.endpoints.victoria-metrics.namespace
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "victoria-metrics-k8s-stack"
                version = "0.89.0" # renovate: datasource=helm depName=victoria-metrics-k8s-stack registryUrl=https://victoriametrics.github.io/helm-charts
                sourceRef = {
                  kind = "HelmRepository"
                  name = local.endpoints.victoria-metrics.name
                }
                interval = "5m"
              }
            }
            releaseName = local.endpoints.victoria-metrics.name
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
                cluster = {
                  dnsDomain = local.domains.kubernetes
                }
              }
              victoria-metrics-operator = {
                enabled = true
                operator = {
                  enable_converter_ownership = true # delete VM CRD when equivalent prometheus CRD is removed
                }
              }
              defaultDashboards = {
                enabled = false
              }
              vmsingle = {
                enabled = false
              }
              vmcluster = {
                enabled = true
                spec = {
                  retentionPeriod = "24h"
                  vmstorage = {
                    extraArgs = {
                      "dedup.minScrapeInterval" = "30s"
                    }
                    resources = {
                      limits = {
                        memory = "1Gi"
                      }
                    }
                  }
                  vmselect = {
                    extraArgs = {
                      "dedup.minScrapeInterval" = "30s"
                    }
                    resources = {
                      limits = {
                        memory = "256Mi"
                      }
                    }
                  }
                  vminsert = {
                    extraArgs = {
                      maxLabelsPerTimeseries = "200"
                    }
                    resources = {
                      limits = {
                        memory = "256Mi"
                      }
                    }
                  }
                }
                route = {
                  select = {
                    enabled = true
                    hostnames = [
                      local.endpoints.victoria-metrics.ingress,
                    ]
                    parentRefs = [
                      {
                        name      = local.endpoints.cilium.name
                        namespace = local.endpoints.cilium.namespace
                      },
                    ]
                    # UI at /select/0/vmui
                  }
                }
              }
              alertmanager = {
                enabled = false
              }
              vmalert = {
                enabled = true
                spec = {
                  port = tostring(local.service_ports.vmalert)
                  extraArgs = {
                    "notifier.blackhole" = "true"
                  }
                  replicaCount = 2
                }
              }
              vmagent = {
                enabled = true
                spec = {
                  scrapeInterval = "30s"
                  replicaCount   = 2
                  globalScrapeMetricRelabelConfigs = [
                    {
                      action = "labeldrop"
                      regex  = "(feature_node_kubernetes_io_.*|beta_amd_com_.*|amd_com_.*|nvidia_com_.*)" # drop excessive labels from NFD
                    },
                  ]
                }
              }
              grafana = {
                enabled = false
              }
              kubeControllerManager = {
                enabled = false
              }
              coreDns = {
                enabled = true
                service = {
                  enabled    = true
                  port       = local.service_ports.coredns_metrics
                  targetPort = local.service_ports.coredns_metrics
                  selector = {
                    k8s-app = "coredns"
                  }
                }
              }
              kubeEtcd = {
                enabled = true
                service = {
                  enabled    = true
                  port       = local.host_ports.etcd_metrics
                  targetPort = local.host_ports.etcd_metrics
                  selector = {
                    component = null
                    k8s-app   = local.endpoints.etcd.name
                  }
                }
                vmScrape = {
                  spec = {
                    jobLabel = "app.kubernetes.io/component"
                    namespaceSelector = {
                      matchNames = []
                    }
                    endpoints = [
                      {
                        port   = "http-metrics"
                        scheme = "http"
                      },
                    ]
                  }
                }
              }
              kubeScheduler = {
                enabled = false
              }
              kubeProxy = {
                enabled = false # using cilium to replace kubeProxy
              }
              kube-state-metrics = {
                enabled  = true
                replicas = 2
                /* This allows kube-state-metrics rule to work, but likely causes flakiness with KubePodNotReady check
                prometheus = {
                  monitor = {
                    enabled = true
                  }
                }
                selfMonitor = {
                  enabled = true
                }
                */
              }
              kubelet = {
                enabled = true
              }
              defaultRules = {
                enabled = true
                groups = {
                  kubernetes-system-controller-manager = {
                    enabled = false
                  }
                  kubernetes-system-scheduler = {
                    enabled = false
                  }
                  kube-state-metrics = {
                    enabled = false # requires kube-state-metrics selfMonitor
                  }
                  "kube-scheduler.rules" = {
                    enabled = false
                  }
                  "kube-prometheus-general.rules" = {
                    enabled = false # fails with count:up0 getting no data
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
  object_name  = "victoria-metrics/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}