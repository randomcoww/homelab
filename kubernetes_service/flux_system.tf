resource "helm_release" "system" {
  name             = "system"
  chart            = "../helm-wrapper"
  namespace        = "kube-system"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  max_history      = 2
  values = [
    yamlencode({ manifests = concat([
      for _, m in [

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
                version = "39.0.5"
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
                  enabled = false
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
                version = "1.20.0"
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
                    memory = "128Mi"
                  }
                  limits = {
                    memory = "128Mi"
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
              cainjector = {
                enabled = false
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

        # cert-issuer
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "cert-issuer"
            namespace = "cert-manager"
          }
          spec = {
            interval = "15m"
            url      = "https://randomcoww.github.io/homelab/"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = "cert-issuer"
            namespace = "cert-manager"
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart = "helm-wrapper"
                sourceRef = {
                  kind = "HelmRepository"
                  name = "cert-issuer"
                }
                interval = "5m"
              }
            }
            releaseName = "cert-issuer"
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
              manifests = [
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
                version = "0.0.36"
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
                version = "3.13.0"
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
                retries = 3
              }
            }
            upgrade = {
              remediation = {
                retries = 3
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
                version = "0.18.3"
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
                retries = 3
              }
            }
            upgrade = {
              remediation = {
                retries = 3
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
            url      = "https://rocm.github.io/k8s-device-plugin/"
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
                version = "0.21.0"
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
                retries = 3
              }
            }
            upgrade = {
              remediation = {
                retries = 3
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
      ],
      module.device-plugin.flux_manifests,
      module.kube-vip.flux_manifests,
      module.registry.flux_manifests,
      module.minio.flux_manifests,
      module.lldap.flux_manifests,
      module.authelia.flux_manifests,
      module.kea.flux_manifests,
    ) }),
  ]
}