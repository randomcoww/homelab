locals {
  victoria-metrics_name      = "vm"
  victoria-metrics_namespace = "monitoring"
  victoria-metrics_port      = 8427
}

resource "minio_s3_object" "fluxcd-victoria-metrics" {
  for_each = {
    "manifest.yaml" = join("\n---\n", [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = local.victoria-metrics_name
            namespace = local.victoria-metrics_namespace
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
            name      = local.victoria-metrics_name
            namespace = local.victoria-metrics_namespace
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "victoria-metrics-k8s-stack"
                version = "0.90.0" # renovate: datasource=helm depName=victoria-metrics-k8s-stack registryUrl=https://victoriametrics.github.io/helm-charts
                sourceRef = {
                  kind = "HelmRepository"
                  name = local.victoria-metrics_name
                }
                interval = "5m"
              }
            }
            releaseName = local.victoria-metrics_name
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
              }
              alertmanager = {
                enabled = false
              }
              vmalert = {
                enabled = true
                spec = {
                  extraArgs = {
                    "notifier.blackhole" = "true"
                  }
                  replicaCount = 2
                }
              }
              vmauth = {
                enabled = true
                spec = {
                  port         = tostring(local.victoria-metrics_port)
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
                  # https://docs.victoriametrics.com/operator/api/#vmagentspec-inlinescrapeconfig
                  inlineScrapeConfig = yamlencode([
                    {
                      job_name = "cri-o"
                      scheme   = "https"
                      tls_config = {
                        ca_file = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
                      }
                      bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
                      kubernetes_sd_configs = [
                        {
                          role = "node"
                        },
                      ]
                      relabel_configs = [
                        {
                          source_labels = ["__meta_kubernetes_node_address_InternalIP"]
                          regex         = "(.+)"
                          target_label  = "__address__"
                          replacement   = "$1:${local.host_ports.crio_metrics}"
                        },
                        {
                          source_labels = ["__meta_kubernetes_node_address_InternalIP"]
                          regex         = "(.+)"
                          target_label  = "instance"
                          replacement   = "$1:${local.host_ports.crio_metrics}"
                        },
                        {
                          source_labels = ["__meta_kubernetes_node_address_Hostname"]
                          action        = "replace"
                          target_label  = "node"
                        },
                      ]
                    },
                  ])
                }
                rbac = {
                  namespaced = false
                  rules = [
                    {
                      nonResourceURLs = ["/metrics", "/metrics/resources", "/metrics/slis"]
                      verbs           = ["get"]
                    },
                  ]
                }
              }
              grafana = {
                enabled = false
              }
              kubeControllerManager = {
                enabled = true
                service = {
                  enabled    = true
                  port       = local.host_ports.controller-manager
                  targetPort = local.host_ports.controller-manager
                }
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
                }
                vmScrape = {
                  spec = {
                    endpoints = [
                      {
                        port   = "http-metrics"
                        scheme = "http" # hit insecure dedicated metrics port
                      },
                    ]
                  }
                }
              }
              kubeScheduler = {
                enabled = true
                service = {
                  enabled    = true
                  port       = local.host_ports.scheduler
                  targetPort = local.host_ports.scheduler
                }
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
                  kube-state-metrics = {
                    enabled = false # requires kube-state-metrics selfMonitor
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