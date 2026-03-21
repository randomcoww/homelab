# Bootstrap

module "bootstrap" {
  source              = "./modules/bootstrap"
  name                = "bootstrap"
  namespace           = "kube-system"
  release             = "0.1.0"
  kubelet_client_user = local.kubernetes.kubelet_client_user
}

# Kubelet CSR approver

resource "helm_release" "kubelet-csr-approver" {
  name             = "kubelet-csr-approver"
  namespace        = "kube-system"
  repository       = "https://postfinance.github.io/kubelet-csr-approver"
  chart            = "kubelet-csr-approver"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  version          = "1.2.13"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
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
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = tostring(local.service_ports.metrics)
        }
      }
    }),
  ]
}

module "kube-proxy" {
  source    = "./modules/kube_proxy"
  name      = "kube-proxy"
  namespace = "kube-system"
  release   = "0.1.0"
  images = {
    kube_proxy = local.container_images_digest.kube_proxy
  }
  ports = {
    kube_proxy         = local.host_ports.kube_proxy
    kube_proxy_metrics = local.host_ports.kube_proxy_metrics
    kube_apiserver     = local.host_ports.apiserver
  }
  kubernetes_pod_prefix = local.networks.kubernetes_pod.prefix
  kube_apiserver_ip     = local.services.apiserver.ip
}

module "flannel" {
  source    = "./modules/flannel"
  name      = "flannel"
  namespace = "kube-system"
  release   = "0.1.0"
  images = {
    flannel            = local.container_images_digest.flannel
    flannel_cni_plugin = local.container_images_digest.flannel_cni_plugin
  }
  ports = {
    healthz = local.host_ports.flannel_healthz
  }
  kubernetes_pod_prefix     = local.networks.kubernetes_pod.prefix
  cni_bridge_interface_name = local.kubernetes.cni_bridge_interface_name
  cni_version               = "0.3.1"
  cni_bin_path              = local.kubernetes.cni_bin_path
  cni_config_path           = local.kubernetes.cni_config_path
}

# Load balancer

module "kube-vip" {
  source    = "./modules/kube_vip"
  name      = "kube-vip"
  namespace = "kube-system"
  release   = "0.1.0"
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
  service_interface = "phy0-service"
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

# Traefik gateway

resource "helm_release" "traefik" {
  name             = local.endpoints.traefik.name
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  namespace        = local.endpoints.traefik.namespace
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  version          = "39.0.6"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
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
    }),
  ]
}

# Basic storage class

resource "helm_release" "local-path-provisioner" {
  name             = "local-path-provisioner"
  namespace        = "kube-system"
  repository       = "https://charts.containeroo.ch"
  chart            = "local-path-provisioner"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  version          = "0.0.36"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
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
    }),
  ]
}

# Internal registry

module "registry" {
  source    = "./modules/registry"
  name      = local.endpoints.registry.name
  namespace = local.endpoints.registry.namespace
  release   = "0.1.0"
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