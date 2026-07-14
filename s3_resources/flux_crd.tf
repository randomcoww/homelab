
# prometheus

module "prometheus" {
  source    = "./modules/prometheus"
  name      = local.endpoints.prometheus.name
  namespace = local.endpoints.prometheus.namespace
  images = {
    thanos = {
      registry   = regex(local.container_image_regex, local.container_images.thanos).repository
      repository = regex(local.container_image_regex, local.container_images.thanos).image
      tag        = regex(local.container_image_regex, local.container_images.thanos).tag
    }
  }
  extra_values = {
    kubeControllerManager = {
      enabled = false
    }
    kubeScheduler = {
      enabled = false
    }
    kubeProxy = {
      enabled = true
      service = {
        enabled    = true
        port       = local.host_ports.kube_proxy_metrics
        targetPort = local.host_ports.kube_proxy_metrics
        selector = {
          app = "kube-proxy"
        }
      }
    }
    coreDns = {
      enabled = true
      service = {
        enabled    = true
        port       = local.service_ports.metrics
        targetPort = local.service_ports.metrics
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
          k8s-app = "etcd"
        }
      }
    }
    kubelet = {
      enabled = true
    }
  }
  extra_scrape_configs = [
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
  ]
  extra_rules_map = {
    minio = {
      groups = [
        {
          name = "minio"
          rules = [
            /*
            {
              alert = "ErasureSetNearingQuorumLoss"
              expr = <<-EOF
              minio_cluster_erasure_set_write_tolerance{app="${local.endpoints.minio.name}",namespace="${local.endpoints.minio.namespace}"} <= 1
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
              minio_cluster_erasure_set_write_tolerance{app="${local.endpoints.minio.name}",namespace="${local.endpoints.minio.namespace}"} <=
              floor(minio_cluster_erasure_set_write_quorum{app="${local.endpoints.minio.name}",namespace="${local.endpoints.minio.namespace}"}/2)
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
              rate(minio_api_requests_5xx_errors_total{app="${local.endpoints.minio.name}",namespace="${local.endpoints.minio.namespace}"}[5m]) > 1
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
              deriv(minio_cluster_health_capacity_usable_free_bytes{app="${local.endpoints.minio.name}",namespace="${local.endpoints.minio.namespace}"}[1h]) / (1024 * 1024 * 1024) < -1
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
              deriv(minio_cluster_health_capacity_usable_free_bytes{app="${local.endpoints.minio.name}",namespace="${local.endpoints.minio.namespace}"}[1h]) / (1024 * 1024 * 1024) > 1
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
              (minio_cluster_health_capacity_usable_free_bytes{app="${local.endpoints.minio.name}",namespace="${local.endpoints.minio.namespace}"} /
              minio_cluster_health_capacity_usable_total_bytes{app="${local.endpoints.minio.name}",namespace="${local.endpoints.minio.namespace}"}) < 0.30
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
              minio_system_process_go_routine_total{app="${local.endpoints.minio.name}",namespace="${local.endpoints.minio.namespace}"} > 10000
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
              deriv(minio_system_process_go_routine_total{app="${local.endpoints.minio.name}",namespace="${local.endpoints.minio.namespace}"}[5m]) > 10
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
              rate(minio_api_requests_4xx_errors_total{app="${local.endpoints.minio.name}",namespace="${local.endpoints.minio.namespace}"}[5m]) > 1
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
              minio_cluster_erasure_set_health{app="${local.endpoints.minio.name}",namespace="${local.endpoints.minio.namespace}"} == 0
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
              minio_system_drive_health{app="${local.endpoints.minio.name}",namespace="${local.endpoints.minio.namespace}"} == 0
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
              minio_system_memory_used_perc{app="${local.endpoints.minio.name}",namespace="${local.endpoints.minio.namespace}"} > 90
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
              deriv(minio_system_memory_used_perc{app="${local.endpoints.minio.name}",namespace="${local.endpoints.minio.namespace}"}[15m]) > 1.25 and
              minio_system_memory_used_perc{app="${local.endpoints.minio.name}",namespace="${local.endpoints.minio.namespace}"} > 50
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
              minio_scanner_last_activity_seconds{app="${local.endpoints.minio.name}",namespace="${local.endpoints.minio.namespace}"} > 172800
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
              (minio_system_process_file_descriptor_open_total{app="${local.endpoints.minio.name}",namespace="${local.endpoints.minio.namespace}"} /
              minio_system_process_file_descriptor_limit_total{app="${local.endpoints.minio.name}",namespace="${local.endpoints.minio.namespace}"}) > 0.90
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
        }
      ]
    }
    kea = {
      groups = [
        {
          name = "kea"
          rules = [
            {
              alert = "KeaDHCP4PoolUsageHigh"
              expr  = <<-EOF
              max by (subnet_id) (
                kea_dhcp4_pool_addresses_assigned_total{app="${local.endpoints.kea.name}",namespace="${local.endpoints.kea.namespace}"} /
                (kea_dhcp4_pool_addresses_total{app="${local.endpoints.kea.name}",namespace="${local.endpoints.kea.namespace}"} + 1)
              ) > 0.90
              EOF
              for   = "10m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Kea DHCPv4 pool usage high"
                description = <<-EOF
                DHCPv4 pool {{ $labels.subnet }} is at {{ $value | humanize }}% utilization.
                EOF
              }
            },
          ]
        },
      ]
    }
  }
  ingress_hostname = local.endpoints.prometheus.ingress
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
  minio_endpoint = "${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket   = "prometheus"
  minio_user     = minio_iam_user.user["prometheus"]
}

module "mountpoint-s3-csi" {
  source    = "./modules/mountpoint_s3_csi"
  name      = local.endpoints.mountpoint_s3_csi.name
  namespace = local.endpoints.mountpoint_s3_csi.namespace
  images = {
    mountpoint_s3_csi = {
      repository = regex(local.container_image_regex, local.container_images.mountpoint_s3_csi).depName
      tag        = regex(local.container_image_regex, local.container_images.mountpoint_s3_csi).currentValue
    }
  }
  kubelet_root_path = local.kubernetes.kubelet_root_path
  minio_user        = minio_iam_user.user["mountpoint_s3_csi"]
}

locals {
  flux_crd = {

    traefik = [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = local.endpoints.traefik.name
            namespace = local.endpoints.traefik.namespace
          }
          spec = {
            interval = "15m"
            url      = "https://traefik.github.io/charts"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = local.endpoints.traefik.name
            namespace = local.endpoints.traefik.namespace
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "traefik"
                version = "41.0.2" # renovate: datasource=helm depName=traefik registryUrl=https://traefik.github.io/charts
                sourceRef = {
                  kind = "HelmRepository"
                  name = local.endpoints.traefik.name
                }
                interval = "5m"
              }
            }
            releaseName = local.endpoints.traefik.name
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
            values = {
              deployment = {
                kind = "DaemonSet"
              }
              api = {
                dashboard = false
              }
              ingressClass = {
                enabled = false
              }
              gateway = {
                name = local.endpoints.traefik.name
                annotations = {
                  "cert-manager.io/cluster-issuer" = local.kubernetes.cert_issuers.acme_prod
                }
                listeners = {
                  websecure = {
                    hostname = "*.${local.domains.public}"
                    port     = 8443
                    protocol = "HTTPS"
                    namespacePolicy = {
                      from = "All"
                    }
                    certificateRefs = [
                      {
                        name  = "${local.domains.public}-tls"
                        kind  = "Secret"
                        group = "core"
                      },
                    ]
                  }
                }
              }
              gatewayClass = {
                name = local.endpoints.traefik.name
              }
              experimental = {
                kubernetesGateway = {
                  enabled = true
                }
              }
              providers = {
                kubernetesCRD = {
                  enabled             = true
                  allowCrossNamespace = true
                }
                kubernetesIngress = {
                  enabled = false
                }
                kubernetesGateway = {
                  enabled = true
                }
              }
              service = {
                spec = {
                  type              = "LoadBalancer"
                  loadBalancerClass = "kube-vip.io/kube-vip-class"
                }
                annotations = {
                  "kube-vip.io/loadbalancerIPs" = local.services.gateway_api.ip
                }
              }
              metrics = {
                prometheus = {
                  service = {
                    enabled = true
                    annotations = {
                      "prometheus.io/scrape" = "true"
                      "prometheus.io/port"   = tostring(local.service_ports.metrics)
                    }
                  }
                }
              }
              ports = {
                web = {
                  expose = {
                    default = true
                  }
                }
                websecure = {
                  expose = {
                    default = true
                  }
                }
              }
              resources = {
                requests = {
                  memory = "128Mi"
                }
                limits = {
                  memory = "128Mi"
                }
              }
            }
          }
        },
      ] :
      yamlencode(m)
    ]

    cert-manager = [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = local.endpoints.cert_manager.name
            namespace = local.endpoints.cert_manager.namespace
          }
          spec = {
            interval = "15m"
            url      = "https://charts.jetstack.io"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = local.endpoints.cert_manager.name
            namespace = local.endpoints.cert_manager.namespace
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "cert-manager"
                version = "1.21.0" # renovate: datasource=helm depName=cert-manager registryUrl=https://charts.jetstack.io
                sourceRef = {
                  kind = "HelmRepository"
                  name = local.endpoints.cert_manager.name
                }
                interval = "5m"
              }
            }
            releaseName = local.endpoints.cert_manager.name
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
            values = {
              replicaCount = 2
              deploymentAnnotations = {
                "certmanager.k8s.io/disable-validation" = "true"
              }
              crds = {
                enabled = true
              }
              enableCertificateOwnerRef = true
              config = {
                enableGatewayAPI = true
              }
              prometheus = {
                enabled = true
              }
              webhook = {
                replicaCount = 2
                resources = {
                  requests = {
                    memory = "256Mi"
                  }
                  limits = {
                    memory = "256Mi"
                  }
                }
              }
              resources = {
                requests = {
                  memory = "256Mi"
                }
                limits = {
                  memory = "256Mi"
                }
              }
              cainjector = {
                enabled      = true
                replicaCount = 2
                resources = {
                  requests = {
                    memory = "256Mi"
                  }
                  limits = {
                    memory = "256Mi"
                  }
                }
              }
              startupapicheck = {
                enabled = true
              }
              extraArgs = [
                "--dns01-recursive-nameservers-only",
                "--dns01-recursive-nameservers=${join(",", [
                  for _, d in local.upstream_dns :
                  "${d.ip}:53"
                ])}",
              ]
              podDnsConfig = {
                options = [
                  {
                    name  = "ndots"
                    value = "2"
                  },
                ]
              }
            }
          }
        },
      ] :
      yamlencode(m)
    ]

    node-feature-discovery = [
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
    ]

    cnpg = [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "cloudnative-pg"
            namespace = "cnpg-system"
          }
          spec = {
            interval = "15m"
            url      = "https://cloudnative-pg.github.io/charts"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "cloudnative-pg"
            namespace = "cnpg-system"
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "cloudnative-pg"
                version = "0.29.0" # renovate: datasource=helm depName=cloudnative-pg registryUrl=https://cloudnative-pg.github.io/charts
                sourceRef = {
                  kind = "HelmRepository"
                  name = "cloudnative-pg"
                }
                interval = "5m"
              }
            }
            releaseName = "cloudnative-pg"
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
            values = {

            }
          }
        },
      ] :
      yamlencode(m)
    ]

    juicefs-csi-driver = [
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
                version = "0.32.0" # renovate: datasource=helm depName=juicefs-csi-driver registryUrl=https://juicedata.github.io/charts
                sourceRef = {
                  kind = "HelmRepository"
                  name = "juicefs-csi-driver"
                }
                interval = "5m"
              }
            }
            releaseName = "juicefs-csi-driver"
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
                    ceMountImage = local.container_images_digest.juicefs
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
                        memory = "512Mi"
                      }
                    }
                  },
                ]
              }
            }
          }
        },
      ] :
      yamlencode(m)
    ]

    prometheus        = module.prometheus.manifests
    mountpoint-s3-csi = module.mountpoint-s3-csi.manifests
  }
}