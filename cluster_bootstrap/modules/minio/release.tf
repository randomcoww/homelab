locals {
  tls_path         = "/opt/minio/certs"
  mount_path       = "/export"
  headless_service = "${var.name}-svc"

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
          namespaceSelector = {
            matchNames = [
              var.namespace,
            ]
          }
          selector = {
            matchLabels = {
              app        = var.name
              monitoring = "true"
            }
          }
          endpoints = [
            {
              path   = "/minio/metrics/v3"
              port   = "https"
              scheme = "https"
              tlsConfig = {
                serverName         = var.service_hostname
                insecureSkipVerify = false
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

      # cert issuer
      {
        apiVersion = "cert-manager.io/v1"
        kind       = "Issuer"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          ca = {
            secretName = module.cert-issuer-secret.name
          }
        }
      },
    ] :
    yamlencode(m)
    ], [
    module.secret.manifest,
    module.cert-issuer-secret.manifest,
    module.service.manifest,
    module.service-headless.manifest,
    module.statefulset.manifest,
  ])
}

module "secret" {
  source    = "../../../modules/secret"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    rootUser     = var.root_user.id
    rootPassword = var.root_user.secret
  }
}

module "cert-issuer-secret" {
  source    = "../../../modules/secret"
  name      = "${var.name}-cert-issuer"
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    "tls.crt" = var.ca.cert_pem
    "tls.key" = var.ca.private_key_pem
  }
}

module "service" {
  source    = "../../../modules/service"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  annotations = {
    "lbipam.cilium.io/ips" = var.service_ip
  }
  labels = {
    monitoring = "true"
  }
  spec = {
    type = "LoadBalancer"
    ports = [
      {
        name       = "https"
        port       = var.service_port
        protocol   = "TCP"
        targetPort = var.service_port
      },
    ]
  }
}

module "service-headless" {
  source    = "../../../modules/service"
  name      = local.headless_service
  namespace = var.namespace
  app       = var.name
  release   = var.release
  spec = {
    type                     = "ClusterIP"
    clusterIP                = "None"
    publishNotReadyAddresses = true
    ports = [
      {
        name       = "https"
        port       = var.service_port
        protocol   = "TCP"
        targetPort = var.service_port
      },
    ]
  }
}

module "statefulset" {
  source = "../../../modules/statefulset"

  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  affinity  = var.affinity
  replicas  = var.replicas
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  spec = {
    serviceName         = local.headless_service
    podManagementPolicy = "Parallel"
    volumeClaimTemplates = [
      {
        apiVersion = "v1"
        kind       = "PersistentVolumeClaim"
        metadata = {
          name = "export"
        }
        spec = {
          accessModes = [
            "ReadWriteOnce",
          ]
          resources = {
            requests = {
              storage = "500Gi"
            }
          }
          storageClassName = "local-path"
          volumeMode       = "Filesystem"
        }
      },
    ]
  }
  template_spec = {
    resources = merge({
      requests = {
        memory = "4Gi"
      }
      limits = {
        memory = "4Gi"
      }
    }, var.resources)
    priorityClassName = "system-node-critical"
    securityContext = {
      fsGroup             = 1000
      fsGroupChangePolicy = "OnRootMismatch"
      runAsGroup          = 1000
      runAsUser           = 1000
    }
    containers = [
      {
        name  = var.name
        image = "${var.images.minio.repository}:${var.images.minio.tag}"
        command = [
          "sh",
          "-ce",
          <<-EOF
          docker-entrypoint.sh \
            minio server https://${var.name}-{0...${var.replicas - 1}}.${local.headless_service}.${var.namespace}${local.mount_path} \
            -S ${local.tls_path} --address :${var.service_port}
          EOF
        ]
        env = [
          {
            name = "MINIO_ROOT_USER"
            valueFrom = {
              secretKeyRef = {
                key  = "rootUser"
                name = module.secret.name
              }
            }
          },
          {
            name = "MINIO_ROOT_PASSWORD"
            valueFrom = {
              secretKeyRef = {
                key  = "rootPassword"
                name = module.secret.name
              }
            }
          },
          {
            name  = "MINIO_PROMETHEUS_AUTH_TYPE"
            value = "public"
          },
          {
            name  = "MINIO_API_REQUESTS_DEADLINE"
            value = "2m"
          },
          {
            name  = "MINIO_STORAGE_CLASS_RRS"
            value = "EC:2"
          },
          {
            name  = "MINIO_STORAGE_CLASS_STANDARD"
            value = "EC:2"
          },
        ]
        port = [
          {
            containerPort = var.service_port
            name          = "https"
            protocol      = "TCP"
          },
        ]
        volumeMounts = [
          {
            mountPath = local.mount_path
            name      = "export"
          },
          {
            mountPath = "${local.tls_path}/public.crt"
            name      = "cert-secret-volume"
            subPath   = "tls.crt"
          },
          {
            mountPath = "${local.tls_path}/private.key"
            name      = "cert-secret-volume"
            subPath   = "tls.key"
          },
          {
            mountPath = "${local.tls_path}/CAs/ca.crt"
            name      = "cert-secret-volume"
            subPath   = "ca.crt"
          },
        ]
        startupProbe = {
          httpGet = {
            scheme = "HTTPS"
            port   = var.service_port
            path   = "/minio/health/live"
          }
          failureThreshold = 10
          periodSeconds    = 15
          timeoutSeconds   = 10
          successThreshold = 1
          failureThreshold = 3
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTPS"
            port   = var.service_port
            path   = "/minio/health/live"
          }
          periodSeconds    = 30
          timeoutSeconds   = 10
          successThreshold = 1
          failureThreshold = 3
        }
        readinessProbe = {
          httpGet = {
            scheme = "HTTPS"
            port   = var.service_port
            path   = "/minio/health/ready"
          }
          periodSeconds    = 15
          timeoutSeconds   = 10
          successThreshold = 1
          failureThreshold = 3
        }
      },
    ]
    volumes = [
      {
        name = "cert-secret-volume"
        csi = {
          driver   = "csi.cert-manager.io"
          readOnly = true
          volumeAttributes = {
            "csi.cert-manager.io/issuer-name" = var.name
            "csi.cert-manager.io/issuer-kind" = "Issuer"
            "csi.cert-manager.io/dns-names" = join(",", [
              "$${POD_NAME}.${local.headless_service}.${var.namespace}",
              var.service_hostname,
            ])
            "csi.cert-manager.io/ip-sans" = join(",", [
              var.service_ip,
            ])
            "csi.cert-manager.io/key-algorithm" = "RSA" # compatibility with iPXE
            "csi.cert-manager.io/key-size"      = "4096"
            "csi.cert-manager.io/key-usages" = join(",", [
              "digital signature",
              "key encipherment",
            ])
          }
        }
      },
    ]
    dnsConfig = {
      options = [
        {
          name  = "ndots"
          value = "5"
        },
      ]
    }
  }
}

resource "helm_release" "wrapper" {
  chart            = "../helm-wrapper"
  name             = var.name
  namespace        = var.namespace
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  max_history      = 2
  timeout          = var.timeout
  values = [
    yamlencode({
      manifests = local.manifests
    }),
  ]
}