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
  version          = "1.2.12"
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
    kube_proxy = local.container_images.kube_proxy
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
    flannel            = local.container_images.flannel
    flannel_cni_plugin = local.container_images.flannel_cni_plugin
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
    kube_vip = local.container_images.kube_vip
  }
  ports = {
    apiserver        = local.host_ports.apiserver,
    kube_vip_metrics = local.host_ports.kube_vip_metrics,
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

# Ingress

resource "helm_release" "ingress-nginx" {
  name             = local.endpoints.ingress_nginx.name
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = local.endpoints.ingress_nginx.namespace
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  version          = "4.14.3"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      controller = {
        kind = "DaemonSet"
        image = {
          digest       = ""
          digestChroot = ""
        }
        admissionWebhooks = {
          patch = {
            image = {
              digest = ""
            }
          }
        }
        ingressClassResource = {
          enabled         = true
          name            = local.endpoints.ingress_nginx.name
          controllerValue = "k8s.io/${local.endpoints.ingress_nginx.name}"
        }
        ingressClass = local.endpoints.ingress_nginx.name
        service = {
          type              = "LoadBalancer"
          loadBalancerIP    = "0.0.0.0"
          loadBalancerClass = "kube-vip.io/kube-vip-class"
        }
        allowSnippetAnnotations = true
        config = {
          # 4.12.0 annotations issue:
          # https://github.com/kubernetes/ingress-nginx/issues/12618
          annotations-risk-level  = "Critical"
          ignore-invalid-headers  = "off"
          proxy-body-size         = 0
          proxy-buffering         = "off"
          proxy-request-buffering = "off"
          ssl-redirect            = "true"
          use-forwarded-headers   = "true"
          keep-alive              = "false"
        }
        controller = {
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
    }),
  ]
}

resource "helm_release" "ingress-nginx-internal" {
  name             = local.endpoints.ingress_nginx_internal.name
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = local.endpoints.ingress_nginx_internal.namespace
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  version          = "4.14.3"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      controller = {
        kind = "DaemonSet"
        image = {
          digest       = ""
          digestChroot = ""
        }
        admissionWebhooks = {
          patch = {
            image = {
              digest = ""
            }
          }
        }
        ingressClassResource = {
          enabled         = true
          name            = local.endpoints.ingress_nginx_internal.name
          controllerValue = "k8s.io/${local.endpoints.ingress_nginx_internal.name}"
        }
        ingressClass = local.endpoints.ingress_nginx_internal.name
        service = {
          type = "ClusterIP"
        }
        allowSnippetAnnotations = true
        config = {
          # 4.12.0 annotations issue:
          # https://github.com/kubernetes/ingress-nginx/issues/12618
          annotations-risk-level  = "Critical"
          ignore-invalid-headers  = "off"
          proxy-body-size         = 0
          proxy-buffering         = "off"
          proxy-request-buffering = "off"
          ssl-redirect            = "true"
          use-forwarded-headers   = "true"
          keep-alive              = "false"
        }
        controller = {
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
  version          = "0.0.35"
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
    registry    = local.container_images.registry
    registry_ui = local.container_images.registry_ui
  }
  ports = {
    registry = local.service_ports.registry
  }
  ca                      = data.terraform_remote_state.sr.outputs.trust.ca
  loadbalancer_class_name = "kube-vip.io/kube-vip-class"

  minio_endpoint      = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket        = "registry"
  minio_bucket_prefix = "/"
  minio_access_secret = local.minio_users.registry.secret
  service_ip          = local.services.registry.ip
  service_hostname    = local.endpoints.registry.service

  ingress_hostname   = local.endpoints.registry.ingress
  ingress_class_name = local.endpoints.ingress_nginx_internal.name
  nginx_ingress_annotations = merge(local.nginx_ingress_annotations_common, {
    "cert-manager.io/cluster-issuer" = local.kubernetes.cert_issuers.ca_internal
  })
}