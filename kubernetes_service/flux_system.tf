resource "helm_release" "system" {
  name             = "system"
  chart            = "../helm-wrapper"
  namespace        = "kube-system"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  max_history      = 2
  values = [
    yamlencode({ manifests = [
      for _, m in [

        # kube-vip
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "kube-vip"
            namespace = "kube-system"
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
            name      = "kube-vip"
            namespace = "kube-system"
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart = "helm-wrapper"
                sourceRef = {
                  kind = "HelmRepository"
                  name = "kube-vip"
                }
                interval = "5m"
              }
            }
            releaseName = "kube-vip"
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
              enable = true
            }
            values = {
              manifests = module.kube-vip.manifests
            }
          }
        },

        # registry
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = local.endpoints.registry.name
            namespace = local.endpoints.registry.namespace
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
            name      = local.endpoints.registry.name
            namespace = local.endpoints.registry.namespace
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart = "helm-wrapper"
                sourceRef = {
                  kind = "HelmRepository"
                  name = local.endpoints.registry.name
                }
                interval = "5m"
              }
            }
            releaseName = local.endpoints.registry.name
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
              enable = true
            }
            values = {
              manifests = module.registry.manifests
            }
          }
        },

        # traefik
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "traefik"
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
                  name = "traefik"
                }
                interval = "5m"
              }
            }
            releaseName = local.endpoints.traefik.name
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
              enable = true
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
                retries = 3
              }
            }
            upgrade = {
              remediation = {
                retries = 3
              }
            }
            test = {
              enable = true
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
                retries = 3
              }
            }
            upgrade = {
              remediation = {
                retries = 3
              }
            }
            test = {
              enable = true
            }
            values = {
              manifests = [
                module.cert-manager-cloudflare-secret.manifest, # DNS update for ACME
                module.cert-manager-issuer-acme-prod-secret.manifest,
                module.cert-manager-issuer-acme-staging-secret.manifest,
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
                                name = "cloudflare-token"
                                key  = "token"
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

                # letsencrypt staging
                yamlencode({
                  apiVersion = "cert-manager.io/v1"
                  kind       = "ClusterIssuer"
                  metadata = {
                    name = local.kubernetes.cert_issuers.acme_staging
                  }
                  spec = {
                    acme = {
                      server = "https://acme-staging-v02.api.letsencrypt.org/directory"
                      email  = data.terraform_remote_state.sr.outputs.letsencrypt.username
                      privateKeySecretRef = {
                        name = module.cert-manager-issuer-acme-staging-secret.name
                      }
                      disableAccountKeyGeneration = true
                      solvers = [
                        {
                          dns01 = {
                            cloudflare = {
                              apiTokenSecretRef = {
                                name = "cloudflare-token"
                                key  = "token"
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
                retries = 3
              }
            }
            upgrade = {
              remediation = {
                retries = 3
              }
            }
            test = {
              enable = true
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

        # minio
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "${local.endpoints.minio.name}-resources"
            namespace = local.endpoints.minio.namespace
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
            name      = "${local.endpoints.minio.name}-resources"
            namespace = local.endpoints.minio.namespace
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart = "helm-wrapper"
                sourceRef = {
                  kind = "HelmRepository"
                  name = "${local.endpoints.minio.name}-resources"
                }
                interval = "5m"
              }
            }
            releaseName = "${local.endpoints.minio.name}-resources"
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
              enable = true
            }
            values = {
              manifests = [
                module.minio-tls.manifest,
                module.minio-metrics-proxy.manifest,
              ]
            }
          }
        },

        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = local.endpoints.minio.name
            namespace = local.endpoints.minio.namespace
          }
          spec = {
            interval = "15m"
            url      = "https://charts.min.io/"
          }
        },
        {
          apiVersion = "helm.toolkit.fluxcd.io/v2"
          kind       = "HelmRelease"
          metadata = {
            name      = local.endpoints.minio.name
            namespace = local.endpoints.minio.namespace
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart   = "minio"
                version = "5.4.0"
                sourceRef = {
                  kind = "HelmRepository"
                  name = local.endpoints.minio.name
                }
                interval = "5m"
              }
            }
            releaseName = local.endpoints.minio.name
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
              enable = true
            }
            values = {
              image = {
                repository = regex(local.container_image_regex, local.container_images.minio).depName
                tag        = regex(local.container_image_regex, local.container_images.minio).tag
              }
              podAnnotations = {
                "checksum/tls"           = sha256(module.minio-tls.manifest)
                "checksum/metrics-proxy" = sha256(module.minio-metrics-proxy.manifest)
              }
              clusterDomain     = local.domains.kubernetes
              mode              = "distributed"
              rootUser          = data.terraform_remote_state.sr.outputs.minio.access_key_id
              rootPassword      = data.terraform_remote_state.sr.outputs.minio.secret_access_key
              priorityClassName = "system-node-critical"
              persistence = {
                storageClass = "local-path"
              }
              drivesPerNode = 1
              replicas      = local.minio_replicas
              resources = {
                requests = {
                  memory = "8Gi"
                }
                limits = {
                  memory = "8Gi"
                }
              }
              service = {
                type              = "LoadBalancer"
                port              = local.service_ports.minio
                clusterIP         = local.services.cluster_minio.ip
                loadBalancerClass = "kube-vip.io/kube-vip-class"
                annotations = {
                  "prometheus.io/scrape"        = "true"
                  "prometheus.io/port"          = tostring(local.service_ports.metrics)
                  "prometheus.io/path"          = "/minio/metrics/v3"
                  "kube-vip.io/loadbalancerIPs" = local.services.minio.ip
                }
              }
              certsPath = "/opt/minio/certs"
              tls = {
                enabled    = true
                publicCrt  = "tls.crt"
                privateKey = "tls.key"
                certSecret = module.minio-tls.name
              }
              trustedCertsSecret = module.minio-tls.name
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
              extraContainers = [
                # bypass TLS for metrics endpoints
                {
                  name  = "${local.endpoints.minio.name}-metrics-proxy"
                  image = local.container_images_digest.nginx
                  ports = [
                    {
                      containerPort = local.service_ports.metrics
                    },
                  ]
                  volumeMounts = [
                    {
                      name      = "metrics-proxy-config"
                      mountPath = "/etc/nginx/conf.d/default.conf"
                      subPath   = "nginx-proxy.conf"
                    },
                  ]
                },
              ]
              extraVolumes = [
                {
                  name = "metrics-proxy-config"
                  configMap = {
                    name = module.minio-metrics-proxy.name
                  }
                },
              ]
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
                              "minio",
                            ]
                          },
                        ]
                      }
                      topologyKey = "kubernetes.io/hostname"
                    },
                  ]
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
              enable = true
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

        # generic device plugin
        {
          apiVersion = "source.toolkit.fluxcd.io/v1"
          kind       = "HelmRepository"
          metadata = {
            name      = "device-plugin"
            namespace = "kube-system"
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
            name      = "device-plugin"
            namespace = "kube-system"
          }
          spec = {
            interval = "15m"
            timeout  = "5m"
            chart = {
              spec = {
                chart = "helm-wrapper"
                sourceRef = {
                  kind = "HelmRepository"
                  name = "device-plugin"
                }
                interval = "5m"
              }
            }
            releaseName = "device-plugin"
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
              enable = true
            }
            values = {
              manifests = module.device-plugin.manifests
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
              enable = true
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
              enable = true
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
    ] }),
  ]
}