locals {
  victoria-metrics_name      = "vm"
  victoria-metrics_namespace = "monitoring"
  victoria-metrics-mcp_name  = "${local.victoria-metrics_name}mcp"
  victoria-metrics-mcp_port  = 8080
  victoria-logs-mcp_name     = "vlmcp"
  victoria-logs-mcp_port     = 8080
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
                version = "0.91.1" # renovate: datasource=helm depName=victoria-metrics-k8s-stack registryUrl=https://victoriametrics.github.io/helm-charts
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
              alertmanager = {
                enabled = true
                config = {
                  route = {
                    receiver        = "slack-monitoring"
                    group_by        = ["alertgroup", "job"]
                    group_wait      = "30s"
                    group_interval  = "5m"
                    repeat_interval = "12h"
                    routes = [
                      {
                        matchers = [
                          "severity=~\"info|warning|critical\"",
                        ]
                        receiver = "slack-monitoring"
                        continue = true
                      },
                    ]
                  }
                  inhibit_rules = [
                    {
                      target_matchers = [
                        "severity=~\"warning|info\"",
                      ]
                      source_matchers = [
                        "severity=critical",
                      ]
                      equal = [
                        "cluster",
                        "namespace",
                        "alertname",
                      ]
                    },
                    {
                      target_matchers = [
                        "severity=info",
                      ]
                      source_matchers = [
                        "severity=warning",
                      ]
                      equal = [
                        "cluster",
                        "namespace",
                        "alertname",
                      ]
                    },
                    {
                      target_matchers = [
                        "severity=info",
                      ]
                      source_matchers = [
                        "alertname=InfoInhibitor",
                      ]
                      equal = [
                        "cluster",
                        "namespace",
                      ]
                    },
                  ]
                  receivers = [
                    {
                      name = "slack-monitoring"
                      slack_configs = [
                        {
                          api_url       = var.slack_alert_webhook
                          channel       = "#bot"
                          send_resolved = true
                          title         = "{{ template \"slack.monzo.title\" . }}"
                          icon_emoji    = "{{ template \"slack.monzo.icon_emoji\" . }}"
                          color         = "{{ template \"slack.monzo.color\" . }}"
                          text          = "{{ template \"slack.monzo.text\" . }}"
                        },
                      ]
                    },
                  ]
                }
              }
              vlcluster = {
                enabled = true
                spec = {
                  vlstorage = {
                    retentionPeriod = "24h"
                    resources = {
                      requests = {
                        memory = "256Mi"
                      }
                      limits = {
                        memory = "512Mi"
                      }
                    }
                  }
                  vlselect = {
                    enabled = true
                    resources = {
                      requests = {
                        memory = "64Mi"
                      }
                      limits = {
                        memory = "128Mi"
                      }
                    }
                  }
                  vlinsert = {
                    enabled = true
                    resources = {
                      requests = {
                        memory = "64Mi"
                      }
                      limits = {
                        memory = "128Mi"
                      }
                    }
                  }
                }
                route = {
                  vlselect = {
                    enabled = true
                    hostnames = [
                      local.endpoints.victoria-logs.hostname,
                    ]
                    parentRefs = [
                      {
                        name      = local.services.cilium.name
                        namespace = local.services.cilium.namespace
                      },
                    ]
                  }
                }
              }
              vlagent = {
                enabled = true
                spec = {
                  port = tostring(local.host_ports.vlagent)
                  containers = [
                    {
                      name = "vlagent"
                      ports = [
                        {
                          containerPort = local.host_ports.vlagent
                          name          = "http"
                          protocol      = "TCP"
                          hostPort      = local.host_ports.vlagent # add this field to default to allow hitting this service from host
                        },
                      ]
                    },
                  ]
                  extraArgs = {
                    "journald.streamFields" = "_HOSTNAME,_SYSTEMD_UNIT,_TRANSPORT"
                  }
                  resources = {
                    requests = {
                      memory = "128Mi"
                    }
                    limits = {
                      memory = "256Mi"
                    }
                  }
                }
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
                      requests = {
                        memory = "1Gi"
                      }
                      limits = {
                        memory = "2Gi"
                      }
                    }
                  }
                  vmselect = {
                    extraArgs = {
                      "dedup.minScrapeInterval"    = "30s"
                      enableMultitenancyViaHeaders = "true"
                    }
                    resources = {
                      requests = {
                        memory = "256Mi"
                      }
                      limits = {
                        memory = "256Mi"
                      }
                    }
                  }
                  vminsert = {
                    extraArgs = {
                      maxLabelsPerTimeseries       = "200"
                      enableMultitenancyViaHeaders = "true"
                    }
                    resources = {
                      requests = {
                        memory = "256Mi"
                      }
                      limits = {
                        memory = "256Mi"
                      }
                    }
                  }
                }
                route = {
                  select = {
                    enabled = true
                    # UI at /select/vmui
                    # query at /select/prometheus/api/*
                    hostnames = [
                      local.endpoints.victoria-metrics.hostname,
                    ]
                    parentRefs = [
                      {
                        name      = local.services.cilium.name
                        namespace = local.services.cilium.namespace
                      },
                    ]
                  }
                }
              }
              vmalert = {
                enabled = true
                spec = {
                  replicaCount = 1 # need to handle some duplicate errors if adding more replicas
                  resources = {
                    requests = {
                      memory = "64Mi"
                    }
                    limits = {
                      memory = "128Mi"
                    }
                  }
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
                  resources = {
                    requests = {
                      memory = "256Mi"
                    }
                    limits = {
                      memory = "256Mi"
                    }
                  }
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
              prometheus-node-exporter = {
                enabled = true
                resources = {
                  requests = {
                    memory = "48Mi"
                  }
                  limits = {
                    memory = "64Mi"
                  }
                }
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
                resources = {
                  limits = {
                    memory = "128Mi"
                  }
                }
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

        # MCP
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = local.victoria-metrics-mcp_name
            namespace = local.victoria-metrics_namespace
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
                  name = local.victoria-metrics_name
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
                entrypoint = "https://${local.endpoints.victoria-metrics.hostname}"
              }
              service = {
                port = local.victoria-metrics-mcp_port
              }
              resources = {
                requests = {
                  memory = "640Mi"
                }
                limits = {
                  memory = "1Gi"
                }
              }
              scrape = {
                enabled = false # TODO: enable after release of https://github.com/VictoriaMetrics/helm-charts/pull/3108
              }
            }
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = local.victoria-logs-mcp_name
            namespace = local.victoria-metrics_namespace
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "victoria-logs-mcp"
                version = "0.1.0" # renovate: datasource=helm depName=victoria-logs-mcp registryUrl=https://victoriametrics.github.io/helm-charts
                sourceRef = {
                  kind = "HelmRepository"
                  name = local.victoria-metrics_name
                }
                interval = "5m"
              }
            }
            releaseName = local.victoria-logs-mcp_name
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
              vl = {
                entrypoint = "https://${local.endpoints.victoria-logs.hostname}"
              }
              service = {
                port = local.victoria-logs-mcp_port
              }
              resources = {
                requests = {
                  memory = "640Mi"
                }
                limits = {
                  memory = "1Gi"
                }
              }
              scrape = {
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
            name = local.victoria-metrics_namespace
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
  object_name  = "victoria-metrics/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}