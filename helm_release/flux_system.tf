resource "helm_release" "system" {
  name                       = "system"
  chart                      = "../helm-wrapper"
  namespace                  = "flux-runners"
  create_namespace           = true
  wait                       = false
  wait_for_jobs              = false
  max_history                = 1
  disable_crd_hooks          = true
  disable_webhooks           = true
  disable_openapi_validation = true
  skip_crds                  = true
  replace                    = true
  render_subchart_notes      = false
  values = [
    yamlencode({ manifests = concat([
      for _, m in [
        # helm-wrapper source
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "wrapper"
            namespace = "flux-runners"
          }
          spec = {
            interval = "15m"
            url      = "https://randomcoww.github.io/homelab"
          }
        },

        # Kubelet CSR approver
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

        # k8s-gateway
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
                loadBalancerIP    = local.services.k8s_gateway.ip
                loadBalancerClass = "kube-vip.io/kube-vip-class"
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

        # traefik
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
                version = "39.0.8" # renovate: datasource=helm depName=traefik registryUrl=https://traefik.github.io/charts
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
                loadBalancerClass = "kube-vip.io/kube-vip-class"
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
              extraObjects = [
                yamlencode({
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
                }),
              ]
            }
          }
        },

        # cert-manager
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "cert-manager"
            namespace = "cert-manager"
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
            name      = "cert-manager"
            namespace = "cert-manager"
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "cert-manager"
                version = "1.20.2" # renovate: datasource=helm depName=cert-manager registryUrl=https://charts.jetstack.io
                sourceRef = {
                  kind = "HelmRepository"
                  name = "cert-manager"
                }
                interval = "5m"
              }
            }
            releaseName = "cert-manager"
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
              extraObjects = [
                # cert issuers and associated secrets #

                module.cert-manager-issuer-acme-prod-secret.manifest,
                module.cert-manager-issuer-ca-internal-secret.manifest,

                # letsencrypt prod
                yamlencode({
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
                }),

                # internal CA
                yamlencode({
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
                }),
              ]
            }
          }
        },

        # local-path-provisioner
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "local-path-provisioner"
            namespace = "kube-system"
          }
          spec = {
            interval = "15m"
            url      = "https://charts.containeroo.ch"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "local-path-provisioner"
            namespace = "kube-system"
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "local-path-provisioner"
                version = "0.0.36" # renovate: datasource=helm depName=local-path-provisioner registryUrl=https://charts.containeroo.ch
                sourceRef = {
                  kind = "HelmRepository"
                  name = "local-path-provisioner"
                }
                interval = "5m"
              }
            }
            releaseName = "local-path-provisioner"
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
              storageClass = {
                create            = true
                name              = "local-path"
                provisionerName   = "rancher.io/local-path"
                defaultClass      = true
                defaultVolumeType = "local"
              }
              nodePathMap = [
                {
                  node = "DEFAULT_PATH_FOR_NON_LISTED_NODES"
                  paths = [
                    "${local.kubernetes.containers_path}/local_path_provisioner",
                  ]
                },
              ]
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

        # metrics-server
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
                version = "3.13.0" # renovate: datasource=helm depName=metrics-server registryUrl=https://kubernetes-sigs.github.io/metrics-server
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

        # node-feature-discovery
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
                version = "0.18.3" # renovate: datasource=helm depName=node-feature-discovery registryUrl=https://kubernetes-sigs.github.io/node-feature-discovery/charts
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

        # AMD GPU
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

        # kured
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
                version = "5.11.0" # renovate: datasource=helm depName=kured registryUrl=https://kubereboot.github.io/charts
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
                rebootSentinelCommand     = "sh -c \"if ([ -f /var/run/reboot-required ] || [ -z $(xargs -n1 -a /proc/cmdline | grep ^coreos.live.rootfs_url=) ]); then exit 0; else exit 1; fi\""
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
      ],
      module.device-plugin.releases,
      module.kube-vip.releases,
      module.registry.releases,
      module.minio.releases,
      module.kea.releases,
      module.prometheus.releases,
      module.tailscale.releases,
    ) }),
  ]
  depends_on = [
    helm_release.flux2,
  ]
}