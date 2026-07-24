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
      enabled = false # using cilium
    }
    coreDns = {
      enabled = true
      service = {
        enabled    = true
        port       = local.service_ports.coredns_metrics
        targetPort = local.service_ports.coredns_metrics
        selector = {
          app = local.endpoints.kube_dns.name
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
          k8s-app = local.endpoints.etcd.name
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
  ingress_hostname = local.endpoints.prometheus.ingress
  gateway_ref = {
    name      = local.endpoints.cilium.name
    namespace = local.endpoints.cilium.namespace
  }
  minio_endpoint = "${local.endpoints.minio.service}:${local.service_ports.minio}"
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
  ca_issuer_name      = local.kubernetes.cert_issuers.ca_internal
  minio_endpoint      = "${local.endpoints.minio.service}:${local.service_ports.minio}"
  minio_bucket        = "registry"
  minio_bucket_prefix = "/"
  minio_user          = minio_iam_user.user["registry"]
  service_port        = local.service_ports.registry
  service_hostname    = local.endpoints.registry.service
  service_ip          = local.endpoints.registry.service_ip
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
  name      = "kea"
  namespace = "netboot"
  images = {
    kea  = local.container_images_digest.kea
    ipxe = local.container_images_digest.ipxe
  }
  service_ips = [
    local.endpoints.kea_primary.cluster_ip,
    local.endpoints.kea_secondary.cluster_ip,
  ]
  ports = {
    kea_peer    = local.host_ports.kea_peer
    kea_metrics = local.host_ports.kea_metrics
    ipxe        = local.host_ports.ipxe
    ipxe_tftp   = local.host_ports.ipxe_tftp
  }
  ipxe_boot_file_name  = "ipxe.efi"
  ipxe_script_base_url = "https://${local.endpoints.minio.service_ip}:${local.service_ports.minio}/boot/ipxe-"
  networks = [
    {
      prefix = local.networks.lan.prefix
      routers = [
        local.vips.gateway.ip,
      ]
      domain_name_servers = [
        local.endpoints.k8s_gateway.service_ip,
      ]
      domain_search = [
        local.domains.kubernetes,
        local.domains.public,
      ]
      classless_static_route = [
        # allow local access to these from clients that set default route over VPN
        for _, prefix in distinct([
          local.networks[local.vips.apiserver.network.name].prefix,
          local.networks.service.prefix,
          local.networks.kubernetes_service.prefix,
        ]) :
        "${prefix} - ${local.vips.gateway.ip}"
      ]
      mtu = lookup(local.networks.lan, "mtu", 1500)
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

    cilium-crs = [
      for _, m in [
        {
          apiVersion = "cilium.io/v2"
          kind       = "CiliumLoadBalancerIPPool"
          metadata = {
            name = "service"
          }
          spec = {
            blocks = [
              {
                start = cidrhost(cidrsubnet(local.networks.service.prefix, 2, 1), 1)
                stop  = cidrhost(local.networks.service.prefix, -2)
              },
            ]
          }
        },
        {
          apiVersion = "gateway.networking.k8s.io/v1"
          kind       = "Gateway"
          metadata = {
            name      = local.endpoints.cilium.name
            namespace = local.endpoints.cilium.namespace
            annotations = {
              "cert-manager.io/cluster-issuer" = local.kubernetes.cert_issuers.acme_prod
            }
          }
          spec = {
            gatewayClassName = "cilium"
            listeners = [
              {
                allowedRoutes = {
                  namespaces = {
                    from = "Same"
                  }
                }
                name     = "web"
                port     = 80
                protocol = "HTTP"
              },
              {
                allowedRoutes = {
                  namespaces = {
                    from = "All"
                  }
                }
                hostname = "*.${local.domains.public}"
                name     = "websecure"
                port     = 443
                protocol = "HTTPS"
                tls = {
                  mode = "Terminate"
                  certificateRefs = [
                    {
                      group = ""
                      name  = "${local.domains.public}-tls"
                    },
                  ]
                }
              },
            ]
          }
        },
      ] :
      yamlencode(m)
    ]

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
                serviceMonitor = {
                  enabled = true
                }
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
                type = "LoadBalancer"
                labels = {
                  app = local.endpoints.k8s_gateway.name
                }
                annotations = {
                  "lbipam.cilium.io/ips" = local.endpoints.k8s_gateway.service_ip
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
                  parameters = "0.0.0.0:${local.service_ports.coredns_metrics}"
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

        # monitoring
        {
          apiVersion = "monitoring.coreos.com/v1"
          kind       = "ServiceMonitor"
          metadata = {
            name      = "k8s-gateway"
            namespace = "kube-system"
          }
          spec = {
            selector = {
              matchLabels = {
                app = "k8s-gateway"
              }
            }
            endpoints = [
              {
                path       = "/metrics"
                targetPort = local.service_ports.coredns_metrics
              },
            ]
          }
        },

        # static service IP
        {
          apiVersion = "cilium.io/v2"
          kind       = "CiliumLoadBalancerIPPool"
          metadata = {
            name = "${local.endpoints.k8s_gateway.namespace}-${local.endpoints.k8s_gateway.name}"
          }
          spec = {
            blocks = [
              {
                cidr = "${local.endpoints.k8s_gateway.service_ip}/32"
              },
            ]
            serviceSelector = {
              matchLabels = {
                "io.kubernetes.service.namespace" = local.endpoints.k8s_gateway.namespace
                "io.kubernetes.service.name"      = local.endpoints.k8s_gateway.name
              }
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
            name      = "kured"
            namespace = "monitoring"
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
            name      = "kured"
            namespace = "monitoring"
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
                  name = "kured"
                }
                interval = "5m"
              }
            }
            releaseName = "kured"
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
                forceReboot       = true
                drainTimeout      = "6m"
                alertFilterRegexp = "^(Watchdog|PrometheusNotConnectedToAlertmanagers)$"
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
              metrics = {
                create    = true
                namespace = "monitoring"
              }
              service = {
                create = true
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

    reloader = [
      for _, m in [
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "reloader"
            namespace = "kube-system"
          }
          spec = {
            interval = "15m"
            url      = "https://stakater.github.io/stakater-charts"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "reloader"
            namespace = "kube-system"
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "reloader"
                version = "2.2.14" # renovate: datasource=helm depName=reloader registryUrl=https://stakater.github.io/stakater-charts
                sourceRef = {
                  kind = "HelmRepository"
                  name = "reloader"
                }
                interval = "5m"
              }
            }
            releaseName = "reloader"
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
              reloader = {
                enableHA         = true
                reloadOnCreate   = true
                syncAfterRestart = true
                logLevel         = "debug"
                deployment = {
                  replicas = 2
                  resources = {
                    requests = {
                      memory = "128Mi"
                    }
                  }
                }
                podMonitor = {
                  enabled = true
                }
              }
            }
          }
        }
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