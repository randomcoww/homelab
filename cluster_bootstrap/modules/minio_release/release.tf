locals {
  manifests = concat([
    for _, m in [
      {
        apiVersion = "monitoring.coreos.com/v1"
        kind       = "ServiceMonitor"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          selector = {
            matchLabels = {
              app        = var.name
              monitoring = "true"
            }
          }
          endpoints = [
            {
              path       = "/minio/metrics/v3"
              targetPort = var.service_port
              scheme     = "https"
              tlsConfig = {
                ca = {
                  secret = {
                    key  = "tls.crt"
                    name = module.tls.name
                  }
                }
                serverName = var.name
              }
            },
          ]
        }
      },
      {
        apiVersion = "monitoring.coreos.com/v1"
        kind       = "PrometheusRule"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          groups = [
            {
              name = var.name
              rules = [
                /*
                {
                  alert = "ErasureSetNearingQuorumLoss"
                  expr = <<-EOF
                  minio_cluster_erasure_set_write_tolerance{job="${var.name}"} <= 1
                  EOF
                  for = "1m"
                  labels = {
                    severity = "critical"
                  }
                  annotations = {
                    summary = "Erasure set {{ $labels.pool_id }}/{{ $labels.set_id }} operating at minimum capacity"
                  }
                },
                {
                  alert = "ErasureSetQuorumLossImminent"
                  expr = <<-EOF
                  minio_cluster_erasure_set_write_tolerance{job="${var.name}"} <=
                  floor(minio_cluster_erasure_set_write_quorum{job="${var.name}"}/2)
                  EOF
                  for = "5m"
                  labels = {
                    severity = "critical"
                  }
                  annotations = {
                    summary = "Erasure set {{ $labels.pool_id }}/{{ $labels.set_id }} at 1/2 write availability"
                  }
                },
                */
                {
                  alert = "HighServerErrorRate"
                  expr  = <<-EOF
                  rate(minio_api_requests_5xx_errors_total{job="${var.name}"}[5m]) > 1
                  EOF
                  for   = "2m"
                  labels = {
                    severity = "critical"
                  }
                  annotations = {
                    summary = "High 5xx error rate on {{ $labels.server }}: {{ $value | humanize }} errors/sec"
                  }
                },
                {
                  alert = "StorageCapacityDecreasing"
                  expr  = <<-EOF
                  deriv(minio_cluster_health_capacity_usable_free_bytes{job="${var.name}"}[1h]) / (1024 * 1024 * 1024) < -1
                  EOF
                  for   = "30m"
                  labels = {
                    severity = "warning"
                  }
                  annotations = {
                    summary = "Cluster storage decreasing rapidly (>1GB/hour)"
                  }
                },
                {
                  alert = "StorageFreeSpaceIncreasing"
                  expr  = <<-EOF
                  deriv(minio_cluster_health_capacity_usable_free_bytes{job="${var.name}"}[1h]) / (1024 * 1024 * 1024) > 1
                  EOF
                  for   = "30m"
                  labels = {
                    severity = "warning"
                  }
                  annotations = {
                    summary = "Cluster free space increasing rapidly (>1GB/hour)"
                  }
                },
                {
                  alert = "StorageCapacityCritical"
                  expr  = <<-EOF
                  (minio_cluster_health_capacity_usable_free_bytes{job="${var.name}"} /
                  minio_cluster_health_capacity_usable_total_bytes{job="${var.name}"}) < 0.30
                  EOF
                  for   = "10m"
                  labels = {
                    severity = "warning"
                  }
                  annotations = {
                    summary = "Cluster storage {{ $value | humanizePercentage }} free (below 30%)"
                  }
                },
                {
                  alert = "GoroutineCountHigh"
                  expr  = <<-EOF
                  minio_system_process_go_routine_total{job="${var.name}"} > 10000
                  EOF
                  for   = "10m"
                  labels = {
                    severity = "warning"
                  }
                  annotations = {
                    summary = "Node {{ $labels.server }} has {{ $value }} goroutines (threshold: 10000)"
                  }
                },
                {
                  alert = "GoroutineCountRapidlyIncreasing"
                  expr  = <<-EOF
                  deriv(minio_system_process_go_routine_total{job="${var.name}"}[5m]) > 10
                  EOF
                  for   = "10m"
                  labels = {
                    severity = "warning"
                  }
                  annotations = {
                    summary = "Goroutine count on {{ $labels.server }} increasing at {{ $value | humanize }}/sec"
                  }
                },
                {
                  alert = "HighClientErrorRate"
                  expr  = <<-EOF
                  rate(minio_api_requests_4xx_errors_total{job="${var.name}"}[5m]) > 1
                  EOF
                  for   = "2m"
                  labels = {
                    severity = "warning"
                  }
                  annotations = {
                    summary = "High 4xx error rate on {{ $labels.server }}: {{ $value | humanize }} errors/sec"
                  }
                },
                {
                  alert = "ErasureSetDegraded"
                  expr  = <<-EOF
                  minio_cluster_erasure_set_health{job="${var.name}"} == 0
                  EOF
                  for   = "15m"
                  labels = {
                    severity = "warning"
                  }
                  annotations = {
                    summary = "Erasure set {{ $labels.pool_id }}/{{ $labels.set_id }} is degraded"
                  }
                },
                {
                  alert = "DriveOffline"
                  expr  = <<-EOF
                  minio_system_drive_health{job="${var.name}"} == 0
                  EOF
                  for   = "10m"
                  labels = {
                    severity = "critical"
                  }
                  annotations = {
                    summary = "Drive {{ $labels.drive }} at index {{ $labels.drive_index }} in server {{$labels.server}} is offline."
                  }
                },
                {
                  alert = "MemoryUsageHigh"
                  expr  = <<-EOF
                  minio_system_memory_used_perc{job="${var.name}"} > 90
                  EOF
                  for   = "10m"
                  labels = {
                    severity = "critical"
                  }
                  annotations = {
                    summary = "Memory usage on {{ $labels.server }} at {{ $value }}%"
                  }
                },
                {
                  alert = "MemoryUsageIncreasing"
                  expr  = <<-EOF
                  deriv(minio_system_memory_used_perc{job="${var.name}"}[15m]) > 1.25 and
                  minio_system_memory_used_perc{job="${var.name}"} > 50
                  EOF
                  for   = "10m"
                  labels = {
                    severity = "warning"
                  }
                  annotations = {
                    summary = "Memory usage on {{ $labels.server }} increasing rapidly ({{ $value }}%/15min)"
                  }
                },
                {
                  alert = "ScannerStalled"
                  expr  = <<-EOF
                  minio_scanner_last_activity_seconds{job="${var.name}"} > 172800
                  EOF
                  for   = "2m"
                  labels = {
                    severity = "warning"
                  }
                  annotations = {
                    summary = "Scanner inactive on {{ $labels.server }} for {{ $value | humanizeDuration }}"
                  }
                },
                {
                  alert = "FileDescriptorExhaustion"
                  expr  = <<-EOF
                  (minio_system_process_file_descriptor_open_total{job="${var.name}"} /
                  minio_system_process_file_descriptor_limit_total{job="${var.name}"}) > 0.90
                  EOF
                  for   = "2m"
                  labels = {
                    severity = "warning"
                  }
                  annotations = {
                    summary = "MinIO process on {{ $labels.server }} using {{ $value | printf \"%.2f\" }}% of available file descriptors"
                  }
                },
              ]
            },
          ]
        }
      },

      # static service IP when using cilium
      {
        apiVersion = "cilium.io/v2"
        kind       = "CiliumLoadBalancerIPPool"
        metadata = {
          name = "${var.namespace}-${var.name}"
        }
        spec = {
          blocks = [
            {
              cidr = "${var.service_ip}/32"
            },
          ]
          serviceSelector = {
            matchLabels = {
              "io.kubernetes.service.namespace" = var.namespace
              "io.kubernetes.service.name"      = var.name
            }
          }
        }
      },
    ] :
    yamlencode(m)
    ], [
    module.tls.manifest,
  ])
}

resource "helm_release" "wrapper" {
  chart            = "../helm-wrapper"
  name             = "${var.name}-resources"
  namespace        = var.namespace
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  max_history      = 2
  values = [
    yamlencode({
      manifests = local.manifests
    }),
  ]
}

resource "helm_release" "minio" {
  name             = var.name
  namespace        = var.namespace
  repository       = "https://charts.min.io"
  chart            = "minio"
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  version          = "5.4.0"
  max_history      = 2
  timeout          = var.timeout
  values = [
    yamlencode({
      image = {
        repository = var.images.minio.repository
        tag        = var.images.minio.tag
      }
      podAnnotations = {
        "checksum/tls" = sha256(module.tls.manifest)
      }
      clusterDomain     = var.cluster_domain
      mode              = "distributed"
      rootUser          = var.root_user.id
      rootPassword      = var.root_user.secret
      priorityClassName = "system-node-critical"
      persistence = {
        storageClass = "local-path"
      }
      drivesPerNode = 1
      replicas      = var.replicas
      resources = {
        requests = {
          memory = "4Gi"
        }
        limits = {
          memory = "4Gi"
        }
      }
      service = {
        type = "LoadBalancer"
        port = var.service_port
        annotations = {
          "lbipam.cilium.io/ips" = var.service_ip
        }
      }
      certsPath = "/opt/minio/certs"
      tls = {
        enabled    = true
        publicCrt  = "tls.crt"
        privateKey = "tls.key"
        certSecret = module.tls.name
      }
      trustedCertsSecret = module.tls.name
      ingress = {
        enabled = false
      }
      environment = {
        MINIO_API_REQUESTS_DEADLINE  = "2m"
        MINIO_STORAGE_CLASS_STANDARD = "EC:2"
        MINIO_STORAGE_CLASS_RRS      = "EC:2"
      }
      buckets        = []
      users          = []
      policies       = []
      customCommands = []
      svcaccts       = []
      affinity = {
        podAntiAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = [
            {
              labelSelector = {
                matchExpressions = [
                  {
                    key      = "app"
                    operator = "In"
                    values = [
                      var.name,
                    ]
                  },
                ]
              }
              topologyKey = "kubernetes.io/hostname"
            },
          ]
        }
      }
      metrics = {
        # this configures for old endpoints. Create a serviceMonitor manually
        serviceMonitor = {
          enabled     = false
          includeNode = false
        }
      }
    }),
  ]
}