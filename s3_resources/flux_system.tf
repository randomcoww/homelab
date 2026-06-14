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
  ca                  = data.terraform_remote_state.host.outputs.internal_ca
  minio_endpoint      = "${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket        = "registry"
  minio_bucket_prefix = "/"
  minio_user          = minio_iam_user.user["registry"]
  service_hostname    = local.endpoints.registry.service
  service_ip          = local.services.registry.ip
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
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
  ports = {
    device_plugin_metrics = local.service_ports.metrics
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

# Tailscale remote access

module "tailscale" {
  source    = "./modules/tailscale"
  name      = "tailscale"
  namespace = "tailscale"
  replicas  = 2
  images = {
    tailscale = local.container_images_digest.tailscale
  }
  tailscale_auth_key = data.terraform_remote_state.sr.outputs.tailscale_auth_key
  extra_envs = [
    {
      name  = "TS_ACCEPT_DNS"
      value = false
    },
    {
      name  = "TS_DEBUG_FIREWALL_MODE"
      value = "nftables"
    },
    {
      name = "TS_EXTRA_ARGS"
      value = join(",", [
        "--advertise-exit-node",
      ])
    },
    {
      name = "TS_ROUTES"
      value = join(",", distinct([
        local.networks[local.services.apiserver.network.name].prefix,
        local.networks.service.prefix,
        local.networks.kubernetes_service.prefix,
      ]))
    },
  ]
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
                version = "3.7.1" # renovate: datasource=helm depName=k8s-gateway registryUrl=https://k8s-gateway.github.io/k8s_gateway
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

    traefik-cr = [
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
                version = "6.0.0" # renovate: datasource=helm depName=kured registryUrl=https://kubereboot.github.io/charts
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
                prometheusUrl = "https://${local.endpoints.prometheus.ingress}"
                period        = "2m"
                metricsPort   = local.service_ports.metrics
                forceReboot   = true
                drainTimeout  = "6m"
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

    device-plugin = module.device-plugin.manifests
    registry      = module.registry.manifests
    kea           = module.kea.manifests
    tailscale     = module.tailscale.manifests
  }
}