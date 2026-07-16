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
                  }
                  serviceMonitor = {
                    enabled = true
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
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "${local.endpoints.cert_manager.name}-csi-driver"
            namespace = local.endpoints.cert_manager.namespace
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "cert-manager-csi-driver"
                version = "0.15.0" # renovate: datasource=helm depName=cert-manager-csi-driver registryUrl=https://charts.jetstack.io
                sourceRef = {
                  kind = "HelmRepository"
                  name = local.endpoints.cert_manager.name
                }
                interval = "5m"
              }
            }
            releaseName = "${local.endpoints.cert_manager.name}-csi-driver"
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
              metrics = {
                enabled = true
                port    = local.service_ports.metrics
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

    cloudnative-pg = [
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
  }
}