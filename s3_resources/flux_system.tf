# prometheus (CRDs created in cluster_bootstrap)

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
    crds = {
      enabled = false # installed earlier in stack
    }
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

# internal registry

module "registry" {
  source    = "./modules/registry"
  name      = local.endpoints.registry.name
  namespace = local.endpoints.registry.namespace
  replicas  = 2
  images = {
    registry = local.container_images_digest.registry
  }
  ports = {
    registry = local.service_ports.registry
    metrics  = local.service_ports.metrics
  }
  ca_issuer_name      = local.kubernetes.cert_issuers.ca_internal
  minio_endpoint      = "${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket        = "registry"
  minio_bucket_prefix = "/"
  minio_user          = minio_iam_user.user["registry"]
  service_hostname    = local.endpoints.registry.service
  service_ip          = local.services.registry.ip
}

# cert-manager

module "cert-manager-issuer-acme-prod-secret" {
  source    = "../modules/secret"
  name      = local.kubernetes.cert_issuers.acme_prod
  namespace = local.endpoints.cert_manager.namespace
  app       = "cert-issuer"
  release   = "0.1.0"
  data = merge({
    "tls.key"        = chomp(data.terraform_remote_state.sr.outputs.letsencrypt.private_key_pem)
    cloudflare-token = data.terraform_remote_state.sr.outputs.cloudflare_dns_api_token
  })
}

module "cert-manager-issuer-ca-internal-secret" {
  source    = "../modules/secret"
  name      = local.kubernetes.cert_issuers.ca_internal
  namespace = local.endpoints.cert_manager.namespace
  app       = "cert-issuer"
  release   = "0.1.0"
  data = merge({
    "tls.crt" = chomp(data.terraform_remote_state.host.outputs.internal_ca.cert_pem)
    "tls.key" = chomp(data.terraform_remote_state.host.outputs.internal_ca.private_key_pem)
  })
}

# Generic device plugin

module "device-plugin" {
  source    = "./modules/device_plugin"
  name      = "device-plugin"
  namespace = "kube-system"
  images = {
    device_plugin = local.container_images_digest.device_plugin
  }
  metrics_port = local.service_ports.metrics
  args = [
    "--device",
    yamlencode({
      name = "rfkill"
      groups = [
        {
          count = 8
          paths = [
            {
              path = "/dev/rfkill"
            },
          ]
        },
      ]
    }),
    "--device",
    yamlencode({
      name = "kvm"
      groups = [
        {
          count = 8
          paths = [
            {
              path = "/dev/kvm"
            },
          ]
        },
      ]
    }),
    "--device",
    yamlencode({
      name = "fuse"
      groups = [
        {
          count = 8
          paths = [
            {
              path = "/dev/fuse"
            },
          ]
        },
      ]
    }),
    "--device",
    yamlencode({
      name = "ntsync"
      groups = [
        {
          count = 8
          paths = [
            {
              path = "/dev/ntsync"
            },
          ]
        },
      ]
    }),
    "--device",
    yamlencode({
      name = "uinput"
      groups = [
        {
          count = 8
          paths = [
            {
              path = "/dev/uinput"
            },
          ]
        },
      ]
    }),
    "--device",
    yamlencode({
      name = "input"
      groups = [
        {
          count = 8
          paths = [
            {
              path = "/dev/input"
              type = "Mount"
            },
          ]
        },
      ]
    }),
    "--device",
    yamlencode({
      name = "tty"
      groups = [
        {
          count = 8
          paths = [
            {
              path = "/dev/tty0"
            },
            {
              path = "/dev/tty1"
            },
          ]
        },
      ]
    }),
    "--device",
    yamlencode({
      name = "dri"
      groups = [
        {
          count = 8
          paths = [
            {
              path = "/dev/dri"
              type = "Mount"
            },
          ]
        },
      ]
    }),
  ]
  kubelet_root_path = local.kubernetes.kubelet_root_path
}

# DHCP

module "kea" {
  source    = "./modules/kea"
  name      = local.endpoints.kea.name
  namespace = local.endpoints.kea.namespace
  images = {
    kea  = local.container_images_digest.kea
    ipxe = local.container_images_digest.ipxe
  }
  service_ips = [
    local.services.cluster_kea_primary.ip,
    local.services.cluster_kea_secondary.ip,
  ]
  ports = {
    kea_peer    = local.host_ports.kea_peer
    kea_metrics = local.host_ports.kea_metrics
    ipxe        = local.host_ports.ipxe
    ipxe_tftp   = local.host_ports.ipxe_tftp
  }
  ipxe_boot_file_name  = "ipxe.efi"
  ipxe_script_base_url = "https://${local.services.minio.ip}:${local.service_ports.minio}/boot/ipxe-"
  networks = [
    {
      prefix = local.networks.lan.prefix
      routers = [
        local.services.gateway.ip,
      ]
      domain_name_servers = [
        local.services.k8s_gateway.ip,
      ]
      domain_search = [
        local.domains.kubernetes,
        local.domains.public,
      ]
      classless_static_route = [
        # allow local access to these from clients that set default route over VPN
        for _, prefix in distinct([
          local.networks[local.services.apiserver.network.name].prefix,
          local.networks.service.prefix,
          local.networks.kubernetes_service.prefix,
        ]) :
        "${prefix} - ${local.services.gateway.ip}"
      ]
      mtu = lookup(local.networks.lan, "mtu", 1500)
    },
    {
      prefix = local.networks.service.prefix
      mtu    = lookup(local.networks.service, "mtu", 1500)
    },
  ]
  timezone = local.timezone
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
  flux_system = {

    kubelet-csr-approver = [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "kubelet-csr-approver"
            namespace = "kube-system"
          }
          spec = {
            interval = "15m"
            url      = "https://postfinance.github.io/kubelet-csr-approver"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "kubelet-csr-approver"
            namespace = "kube-system"
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "kubelet-csr-approver"
                version = "1.2.14" # renovate: datasource=helm depName=kubelet-csr-approver registryUrl=https://postfinance.github.io/kubelet-csr-approver
                sourceRef = {
                  kind = "HelmRepository"
                  name = "kubelet-csr-approver"
                }
                interval = "5m"
              }
            }
            releaseName = "kubelet-csr-approver"
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
              global = {
                clusterDomain = local.domains.kubernetes
              }
              providerRegex       = "^k-\\d+$"
              bypassDnsResolution = true
              bypassHostnameCheck = true
              providerIpPrefixes = [
                local.networks.service.prefix,
              ]
              metrics = {
                enable = true
                port   = local.service_ports.metrics
              }
            }
          }
        },
      ] :
      yamlencode(m)
    ]

    k8s-gateway = [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = local.endpoints.k8s_gateway.name
            namespace = local.endpoints.k8s_gateway.namespace
          }
          spec = {
            interval = "15m"
            url      = "https://k8s-gateway.github.io/k8s_gateway"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = local.endpoints.k8s_gateway.name
            namespace = local.endpoints.k8s_gateway.namespace
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "k8s-gateway"
                version = "3.7.2" # renovate: datasource=helm depName=k8s-gateway registryUrl=https://k8s-gateway.github.io/k8s_gateway
                sourceRef = {
                  kind = "HelmRepository"
                  name = local.endpoints.k8s_gateway.name
                }
                interval = "5m"
              }
            }
            releaseName = local.endpoints.k8s_gateway.name
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
              domain = "."
              watchedResources = [
                "Service",
                "HTTPRoute",
              ]
              fallthrough = {
                enabled = true
              }
              resources = {
                requests = {
                  memory = "128Mi"
                }
                limits = {
                  memory = "128Mi"
                }
              }
              service = {
                type              = "LoadBalancer"
                loadBalancerClass = "kube-vip.io/kube-vip-class"
                annotations = {
                  "kube-vip.io/loadbalancerIPs" = local.services.k8s_gateway.ip
                }
              }
              customLabels = {
                app = local.endpoints.k8s_gateway.name
              }
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
                              local.endpoints.k8s_gateway.name,
                            ]
                          },
                        ]
                      }
                      topologyKey = "kubernetes.io/hostname"
                    },
                  ]
                }
              }
              replicaCount = 3
              extraZonePlugins = concat([
                {
                  name = "health"
                },
                {
                  name = "ready"
                },
                {
                  name = "loop"
                },
                {
                  name       = "prometheus"
                  parameters = "0.0.0.0:9153" # not configurable
                },
                {
                  name = "hosts"
                  configBlock = join("\n", concat(compact([
                    for _, host in local.hosts :
                    try("${cidrhost(host.networks.service.prefix, host.netnum)} ${host.fqdn}", "")
                    ]), [
                    "fallthrough"
                  ]))
                },
                ], [
                for tlshostname, ips in merge({
                  for _, d in local.upstream_dns :
                  d.hostname => d.ip...
                }) :
                {
                  name = "forward"
                  parameters = ". ${join(" ", [
                    for _, ip in ips :
                    "tls://${ip}"
                  ])}"
                  configBlock = <<-EOF
                  tls_servername ${tlshostname}
                  health_check 5s
                  EOF
                }
              ])
            }
          }
        },
      ] :
      yamlencode(m)
    ]

    traefik-crs = [
      for _, m in [
        {
          apiVersion = "traefik.io/v1alpha1"
          kind       = "Middleware"
          metadata = {
            name      = "forwardauth-authelia"
            namespace = local.endpoints.traefik.namespace
          }
          spec = {
            forwardAuth = {
              address            = "http://${local.endpoints.authelia.service_fqdn}/api/authz/forward-auth"
              trustForwardHeader = true
              authResponseHeaders = [
                "Remote-User",
                "Remote-Groups",
                "Remote-Email",
                "Remote-Name",
              ]
            }
          }
        },
      ] :
      yamlencode(m)
    ]

    cert-manager-cr = concat([
      for _, m in [
        # letsencrypt prod
        {
          apiVersion = "cert-manager.io/v1"
          kind       = "ClusterIssuer"
          metadata = {
            name = local.kubernetes.cert_issuers.acme_prod
          }
          spec = {
            acme = {
              server = "https://acme-v02.api.letsencrypt.org/directory"
              email  = data.terraform_remote_state.sr.outputs.letsencrypt.username
              privateKeySecretRef = {
                name = module.cert-manager-issuer-acme-prod-secret.name
              }
              disableAccountKeyGeneration = true
              solvers = [
                {
                  dns01 = {
                    cloudflare = {
                      apiTokenSecretRef = {
                        name = module.cert-manager-issuer-acme-prod-secret.name
                        key  = "cloudflare-token"
                      }
                    }
                  }
                  selector = {
                    dnsZones = [
                      local.domains.public,
                    ]
                  }
                },
              ]
            }
          }
        },

        # internal CA
        {
          apiVersion = "cert-manager.io/v1"
          kind       = "ClusterIssuer"
          metadata = {
            name = local.kubernetes.cert_issuers.ca_internal
          }
          spec = {
            ca = {
              secretName = module.cert-manager-issuer-ca-internal-secret.name
            }
          }
        },
      ] :
      yamlencode(m)
      ], [
      module.cert-manager-issuer-acme-prod-secret.manifest,
      module.cert-manager-issuer-ca-internal-secret.manifest,
    ])

    metrics-server = [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "metrics-server"
            namespace = "kube-system"
          }
          spec = {
            interval = "15m"
            url      = "https://kubernetes-sigs.github.io/metrics-server"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "metrics-server"
            namespace = "kube-system"
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "metrics-server"
                version = "3.13.1" # renovate: datasource=helm depName=metrics-server registryUrl=https://kubernetes-sigs.github.io/metrics-server
                sourceRef = {
                  kind = "HelmRepository"
                  name = "metrics-server"
                }
                interval = "5m"
              }
            }
            releaseName = "metrics-server"
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
              replicas = 2
              defaultArgs = [
                "--cert-dir=/tmp",
                "--metric-resolution=15s",
                "--kubelet-preferred-address-types=InternalIP",
                "--kubelet-use-node-status-port",
                "--v=2",
              ]
              podLabels = {
                app = "metrics-server"
              }
              resources = {
                requests = {
                  memory = "200Mi"
                }
                limits = {
                  memory = "200Mi"
                }
              }
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
                              "metrics-server",
                            ]
                          },
                        ]
                      }
                      topologyKey = "kubernetes.io/hostname"
                    },
                  ]
                }
              }
              dnsConfig = {
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

    amd-gpu = [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "amd-gpu"
            namespace = "amd"
          }
          spec = {
            interval = "15m"
            url      = "https://rocm.github.io/k8s-device-plugin"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "amd-gpu"
            namespace = "amd"
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "amd-gpu"
                version = "0.21.0" # renovate: datasource=helm depName=amd-gpu registryUrl=https://rocm.github.io/k8s-device-plugin
                sourceRef = {
                  kind = "HelmRepository"
                  name = "amd-gpu"
                }
                interval = "5m"
              }
            }
            releaseName = "amd-gpu"
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
              nfd = {
                enabled = false
              }
              labeller = {
                enabled = true
              }
              dp = {
                resources = {
                  requests = {
                    memory = "64Mi"
                  }
                  limits = {
                    memory = "64Mi"
                  }
                }
              }
              lbl = {
                resources = {
                  requests = {
                    memory = "64Mi"
                  }
                  limits = {
                    memory = "64Mi"
                  }
                }
              }
            }
          }
        },
      ] :
      yamlencode(m)
    ]

    kured = [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = local.endpoints.kured.name
            namespace = local.endpoints.kured.namespace
          }
          spec = {
            interval = "15m"
            url      = "https://kubereboot.github.io/charts"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = local.endpoints.kured.name
            namespace = local.endpoints.prometheus.namespace
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "kured"
                version = "6.1.0" # renovate: datasource=helm depName=kured registryUrl=https://kubereboot.github.io/charts
                sourceRef = {
                  kind = "HelmRepository"
                  name = local.endpoints.kured.name
                }
                interval = "5m"
              }
            }
            releaseName = local.endpoints.kured.name
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
              # manifest #

              configuration = {
                prometheusUrl     = "https://${local.endpoints.prometheus.ingress}"
                period            = "2m"
                metricsPort       = local.service_ports.metrics
                forceReboot       = true
                drainTimeout      = "6m"
                alertFilterRegexp = "^Watchdog$|^PrometheusNotConnectedToAlertmanagers$"
                blockingPodSelector = [
                  "app.kubernetes.io/part-of=gha-runner-scale-set,app.kubernetes.io/component=runner",
                ]
                timeZone = local.timezone
                # trigger reboot if either /var/run/reboot-required is set, or node failed network boot
                useRebootSentinelHostPath = false
                rebootSentinelCommand     = "reboot-required.sh"
              }
              resources = {
                requests = {
                  memory = "128Mi"
                }
                limits = {
                  memory = "128Mi"
                }
              }
              priorityClassName = "system-node-critical"
              service = {
                create = true
                annotations = {
                  "prometheus.io/scrape" = "true"
                  "prometheus.io/port"   = tostring(local.service_ports.metrics)
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
                  name = "ca-trust-bundle"
                  hostPath = {
                    path = "/etc/ssl/certs/ca-certificates.crt"
                    type = "File"
                  }
                },
              ]
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
    registry          = module.registry.manifests
    device-plugin     = module.device-plugin.manifests
    kea               = module.kea.manifests
    mountpoint-s3-csi = module.mountpoint-s3-csi.manifests
  }
}