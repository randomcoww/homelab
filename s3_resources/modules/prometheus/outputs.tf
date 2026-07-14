output "manifests" {
  value = [
    for _, m in [
      {
        apiVersion = "source.toolkit.fluxcd.io/v1"
        kind       = "HelmRepository"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          interval = "15m"
          url      = "https://prometheus-community.github.io/helm-charts"
        }
      },
      {
        apiVersion = "helm.toolkit.fluxcd.io/v2"
        kind       = "HelmRelease"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          interval = "15m"
          timeout  = "5m"
          chart = {
            spec = {
              chart   = "kube-prometheus-stack"
              version = "87.12.2" # renovate: datasource=helm depName=kube-prometheus-stack registryUrl=https://prometheus-community.github.io/helm-charts
              sourceRef = {
                kind = "HelmRepository"
                name = var.name
              }
              interval = "5m"
            }
          }
          releaseName = var.name
          install = {
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
          values = merge({
            namespaceOverride = var.namespace
            defaultRules = {
              create = true
              rules = {
                alertmanager = false
                windows      = false
              }
            }
            alertmanager = {
              enabled = false
            }
            grafana = {
              enabled = false
            }
            additionalPrometheusRulesMap = merge({
            }, var.extra_rules_map)
            prometheus = {
              enabled = true
              thanosService = {
                enabled = true
                port    = local.ports.thanos_sidecar
              }
              service = {
                enabled = true
                additionalPorts = [
                  {
                    name       = "thanos-querier"
                    port       = local.ports.thanos_querier
                    targetPort = local.ports.thanos_querier
                  },
                ]
              }
              kubeletService = {
                enabled = true
              }
              kubeletEndpointsEnabled = false
              route = {
                main = {
                  enabled = true
                  parentRefs = [
                    var.gateway_ref,
                  ]
                  hostnames = [
                    var.ingress_hostname,
                  ]
                  additionalRules = [
                    {
                      matches = [
                        for _, p in [
                          "/api/v1/query",
                          "/api/v1/query_range",
                          "/api/v1/series",
                          "/api/v1/labels",
                          "/api/v1/label",
                          "/api/v1/metadata",
                          "/api/v1/query_exemplars",
                          "/api/v1/rules",
                          "/api/v1/alerts",
                        ] :
                        {
                          path = {
                            type  = "PathPrefix"
                            value = p
                          }
                        }
                      ]
                      backendRefs = [
                        {
                          name = "${var.name}-kube-prometheus-prometheus"
                          port = local.ports.thanos_querier
                        },
                      ]
                    },
                  ]
                }
              }
              prometheusSpec = {
                disableCompaction        = true
                replicaExternalLabelName = "replica" # value is fixed in thanos
                thanos = {
                  objectStorageConfig = {
                    secret = {
                      type = "S3"
                      config = {
                        bucket     = var.minio_bucket
                        endpoint   = var.minio_endpoint
                        access_key = var.minio_user.id
                        secret_key = var.minio_user.secret
                      }
                    }
                  }
                  volumeMounts = [
                    {
                      name      = "ca-trust-bundle"
                      mountPath = "/etc/ssl/certs/ca-certificates.crt"
                      readOnly  = true
                    },
                  ]
                }
                service = {
                  enabled    = true
                  port       = local.ports.prometheus
                  targetPort = local.ports.prometheus
                }
                containers = [
                  {
                    name  = "thanos-querier"
                    image = var.images.thanos
                    args = [
                      "query",
                      "--query.replica-label=replica",
                      "--http-address=0.0.0.0:${local.ports.thanos_querier}",
                      "--grpc-address=127.0.0.1:50903", # unused
                      "--endpoint=dnssrv+_grpc._tcp.${var.name}-kube-prometheus-thanos-discovery.${var.namespace}:${local.ports.thanos_sidecar}",
                      "--endpoint=dnssrv+_grpc._tcp.${var.name}-kube-prometheus-thanos-discovery.${var.namespace}:${local.ports.thanos_store}",
                    ]
                    env = [
                      {
                        name = "POD_NAME"
                        valueFrom = {
                          fieldRef = {
                            fieldPath = "metadata.name"
                          }
                        }
                      },
                    ]
                    ports = [
                      {
                        containerPort = local.ports.thanos_querier
                      },
                    ]
                    volumeMounts = [
                    ]
                    livenessProbe = {
                      httpGet = {
                        scheme = "HTTP"
                        port   = local.ports.thanos_querier
                        path   = "/-/healthy"
                      }
                      initialDelaySeconds = 10
                      timeoutSeconds      = 2
                    }
                    readinessProbe = {
                      httpGet = {
                        scheme = "HTTP"
                        port   = local.ports.thanos_querier
                        path   = "/-/ready"
                      }
                    }
                  },
                  {
                    name  = "thanos-store"
                    image = var.images.thanos
                    args = [
                      "store",
                      "--data-dir=${local.store_data_path}",
                      "--http-address=0.0.0.0:${local.ports.thanos_store_probe}",
                      "--grpc-address=0.0.0.0:${local.ports.thanos_store}",
                      <<-EOF
                      --objstore.config=${yamlencode(local.thanos_object_config)}
                      EOF
                    ]
                    env = [
                      {
                        name = "POD_NAME"
                        valueFrom = {
                          fieldRef = {
                            fieldPath = "metadata.name"
                          }
                        }
                      },
                      {
                        name = "AWS_ACCESS_KEY_ID"
                        valueFrom = {
                          secretKeyRef = {
                            name = module.minio-user-secret.name
                            key  = "AWS_ACCESS_KEY_ID"
                          }
                        }
                      },
                      {
                        name = "AWS_SECRET_ACCESS_KEY"
                        valueFrom = {
                          secretKeyRef = {
                            name = module.minio-user-secret.name
                            key  = "AWS_SECRET_ACCESS_KEY"
                          }
                        }
                      },
                    ]
                    ports = [
                      {
                        containerPort = local.ports.thanos_store
                      },
                    ]
                    volumeMounts = [
                      {
                        name      = "thanos-store-data"
                        mountPath = local.store_data_path
                      },
                      {
                        name      = "ca-trust-bundle"
                        mountPath = "/etc/ssl/certs/ca-certificates.crt"
                        readOnly  = true
                      },
                    ]
                    livenessProbe = {
                      httpGet = {
                        scheme = "HTTP"
                        port   = local.ports.thanos_store_probe
                        path   = "/-/healthy"
                      }
                      initialDelaySeconds = 10
                      timeoutSeconds      = 2
                    }
                    readinessProbe = {
                      httpGet = {
                        scheme = "HTTP"
                        port   = local.ports.thanos_store_probe
                        path   = "/-/ready"
                      }
                    }
                  },
                ]
                storageSpec = {
                  volumeClaimTemplate = {
                    spec = {
                      storageClassName = "local-path"
                      accessModes = [
                        "ReadWriteOnce",
                      ]
                      resources = {
                        requests = {
                          storage = "16Gi"
                        }
                      }
                    }
                  }
                }
                volumeMounts = [
                  {
                    name      = "ca-trust-bundle"
                    mountPath = "/etc/ssl/certs/ca-certificates.crt"
                    readOnly  = true
                  },
                ]
                volumes = [
                  {
                    name = "thanos-store-data"
                    emptyDir = {
                      medium = "Memory"
                    }
                  },
                  {
                    name = "ca-trust-bundle"
                    hostPath = {
                      path = "/etc/ssl/certs/ca-certificates.crt"
                      type = "File"
                    }
                  },
                ]
                retention = "6h"
                resources = {
                  requests = {
                    memory = "6Gi"
                  }
                }
                replicas = var.replicas
                dnsConfig = {
                  options = [
                    {
                      name  = "ndots"
                      value = "2"
                    },
                  ]
                }
                podLabels = {
                  app = var.name
                }
                additionalScrapeConfigs = concat(yamldecode(<<-EOF
                  - job_name: kubernetes-service-endpoints
                    honor_labels: true
                    kubernetes_sd_configs:
                      - role: endpointslice
                    relabel_configs:
                      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
                        action: keep
                        regex: true
                      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape_slow]
                        action: drop
                        regex: true
                      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
                        action: replace
                        target_label: __scheme__
                        regex: (https?)
                      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
                        action: replace
                        target_label: __metrics_path__
                        regex: (.+)
                      - source_labels:
                        - __address__
                        - __meta_kubernetes_service_annotation_prometheus_io_port
                        action: replace
                        target_label: __address__
                        regex: (.+?)(?::\d+)?;(\d+)
                        replacement: $1:$2
                      - action: labelmap
                        regex: __meta_kubernetes_service_annotation_prometheus_io_param_(.+)
                        replacement: __param_$1
                      - action: labelmap
                        regex: __meta_kubernetes_service_label_(.+)
                      - source_labels: [__meta_kubernetes_namespace]
                        action: replace
                        target_label: namespace
                      - source_labels: [__meta_kubernetes_service_name]
                        action: replace
                        target_label: service
                      - source_labels: [__meta_kubernetes_pod_node_name]
                        action: replace
                        target_label: node

                  - job_name: kubernetes-pods
                    honor_labels: true
                    kubernetes_sd_configs:
                      - role: pod
                    relabel_configs:
                      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
                        action: keep
                        regex: true
                      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape_slow]
                        action: drop
                        regex: true
                      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scheme]
                        action: replace
                        regex: (https?)
                        target_label: __scheme__
                      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
                        action: replace
                        target_label: __metrics_path__
                        regex: (.+)
                      - source_labels:
                        - __meta_kubernetes_pod_annotation_prometheus_io_port
                        - __meta_kubernetes_pod_ip
                        action: replace
                        regex: (\d+);(([A-Fa-f0-9]{1,4}::?){1,7}[A-Fa-f0-9]{1,4})
                        replacement: '[$2]:$1'
                        target_label: __address__
                      - source_labels:
                        - __meta_kubernetes_pod_annotation_prometheus_io_port
                        - __meta_kubernetes_pod_ip
                        action: replace
                        regex: (\d+);((([0-9]+?)(\.|$)){4})
                        replacement: $2:$1
                        target_label: __address__
                      - action: labelmap
                        regex: __meta_kubernetes_pod_annotation_prometheus_io_param_(.+)
                        replacement: __param_$1
                      - action: labelmap
                        regex: __meta_kubernetes_pod_label_(.+)
                      - source_labels: [__meta_kubernetes_namespace]
                        action: replace
                        target_label: namespace
                      - source_labels: [__meta_kubernetes_pod_name]
                        action: replace
                        target_label: pod
                      - source_labels: [__meta_kubernetes_pod_phase]
                        regex: Pending|Succeeded|Failed|Completed
                        action: drop
                      - source_labels: [__meta_kubernetes_pod_node_name]
                        action: replace
                        target_label: node
                  EOF
                ), var.extra_scrape_configs)
              }
            }
            extraManifests = concat([
              module.minio-user-secret.manifest,
              yamlencode(local.compactor_job),
            ], var.extra_manifests)
          }, var.extra_values)
        }
      },
    ] :
    yamlencode(m)
  ]
}