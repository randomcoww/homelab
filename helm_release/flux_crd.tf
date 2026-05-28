locals {
  flux_crd = merge({

    traefik = {
      "release.yaml" = join("---\n", [
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
                  version = "40.2.0" # renovate: datasource=helm depName=traefik registryUrl=https://traefik.github.io/charts
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
              }
            }
          },
        ] :
        yamlencode(m)
      ])
      "kustomization.yaml" = yamlencode({
        apiVersion = "kustomize.config.k8s.io/v1beta1"
        kind       = "Kustomization"
        namespace  = local.endpoints.traefik.namespace
        resources = [
          "release.yaml",
        ]
      })
    }

    cert-manager = {
      "release.yaml" = join("---\n", [
        for _, m in [
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
              }
            }
          },
        ] :
        yamlencode(m)
      ])
      "kustomization.yaml" = yamlencode({
        apiVersion = "kustomize.config.k8s.io/v1beta1"
        kind       = "Kustomization"
        namespace  = "cert-manager"
        resources = [
          "release.yaml",
        ]
      })
    }

    node-feature-discovery = {
      "release.yaml" = join("---\n", [
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
        ] :
        yamlencode(m)
      ])
      "kustomization.yaml" = yamlencode({
        apiVersion = "kustomize.config.k8s.io/v1beta1"
        kind       = "Kustomization"
        namespace  = "kube-system"
        resources = [
          "release.yaml",
        ]
      })
    }

    }, {
    for _, m in [
        module.prometheus,
      ] :
      m.name => m.kustomize
    })
  }