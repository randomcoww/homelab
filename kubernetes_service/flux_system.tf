# Load balancer

module "kube-vip" {
  source    = "./modules/kube_vip"
  name      = "kube-vip"
  namespace = "kube-system"
  images = {
    kube_vip = local.container_images_digest.kube_vip
  }
  ports = {
    apiserver        = local.host_ports.apiserver,
    kube_vip_metrics = local.host_ports.kube_vip_metrics,
    kube_vip_health  = local.host_ports.kube_vip_health,
  }
  bgp_as     = local.ha.bgp_as
  bgp_peeras = local.ha.bgp_as
  bgp_neighbor_ips = [
    for _, host in local.members.gateway :
    cidrhost(local.networks.service.prefix, host.netnum)
  ]
  apiserver_ip      = local.services.apiserver.ip
  service_interface = "phy-service"
  affinity = {
    nodeAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = {
        nodeSelectorTerms = [
          {
            matchExpressions = [
              {
                key      = "node-role.kubernetes.io/control-plane"
                operator = "Exists"
              },
            ]
          },
        ]
      }
    }
  }
}

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
  ca                      = data.terraform_remote_state.sr.outputs.trust.ca
  loadbalancer_class_name = "kube-vip.io/kube-vip-class"

  minio_endpoint      = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket        = "registry"
  minio_bucket_prefix = "/"
  minio_access_secret = local.minio_users.registry.secret
  service_ip          = local.services.registry.ip
  service_hostname    = local.endpoints.registry.service
  ui_ingress_hostname = local.endpoints.registry.ingress
  gateway_ref = {
    name      = local.endpoints.traefik.name
    namespace = local.endpoints.traefik.namespace
  }
}

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
      ] :
      yamlencode(m)
    ] }),
  ]
}