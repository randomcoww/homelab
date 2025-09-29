## Hack to release custom charts as local chart

locals {
  modules_enabled = [
    # bootstrap
    module.bootstrap,
    module.kube-proxy,
    module.flannel,
    module.kapprover,
    module.kube-vip,
    # services
    module.device-plugin,
    module.kea,
    module.matchbox,
    module.tailscale,
    module.hostapd,
    module.qrcode-hostapd,
    module.webdav-pictures,
    module.webdav-videos,
    module.audioserve,
    module.vaultwarden,
    module.flowise,
    module.searxng,
    module.registry,
    module.registry-ui,
    # module.code-server,
    module.llama-cpp,
    # module.sunshine-desktop,
  ]
}

# bootstrap

module "bootstrap" {
  source    = "./modules/bootstrap"
  name      = "bootstrap"
  namespace = "kube-system"
  release   = "0.1.1"

  node_bootstrap_user = local.kubernetes.node_bootstrap_user
  kubelet_client_user = local.kubernetes.kubelet_client_user
}

module "kube-proxy" {
  source    = "./modules/kube_proxy"
  name      = "kube-proxy"
  namespace = "kube-system"
  release   = "0.1.2"
  images = {
    kube_proxy = local.container_images.kube_proxy
  }
  ports = {
    kube_proxy     = local.host_ports.kube_proxy
    kube_apiserver = local.host_ports.apiserver
  }
  kubernetes_pod_prefix = local.networks.kubernetes_pod.prefix
  kube_apiserver_ip     = local.services.apiserver.ip
}

module "flannel" {
  source    = "./modules/flannel"
  name      = "flannel"
  namespace = "kube-system"
  release   = "0.1.2"
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
}

module "kapprover" {
  source    = "./modules/kapprover"
  name      = "kapprover"
  namespace = "kube-system"
  release   = "0.1.1"
  replicas  = 2
  images = {
    kapprover = local.container_images.kapprover
  }
}

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

resource "helm_release" "local-path-provisioner" {
  name          = "local-path-provisioner"
  namespace     = "kube-system"
  repository    = "https://charts.containeroo.ch"
  chart         = "local-path-provisioner"
  wait          = false
  wait_for_jobs = false
  version       = "0.0.33"
  max_history   = 2
  values = [
    yamlencode({
      replicaCount = 2
      storageClass = {
        name         = "local-path"
        defaultClass = true
      }
      nodePathMap = [
        {
          node  = "DEFAULT_PATH_FOR_NON_LISTED_NODES"
          paths = ["${local.kubernetes.containers_path}/local_path_provisioner"]
        },
      ]
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
  ]
}

# nginx ingress #

resource "helm_release" "ingress-nginx" {
  for_each = local.kubernetes.ingress_classes

  name             = each.value
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = local.kubernetes_services[each.key].namespace
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  version          = "4.13.2"
  max_history      = 2
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
          name            = each.value
          controllerValue = "k8s.io/${each.value}"
        }
        ingressClass = each.value
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
  depends_on = [
    kubernetes_labels.labels,
  ]
}

# Nvidia GPU

resource "helm_release" "nvidia-gpu-oprerator" {
  name             = "gpu-operator"
  namespace        = "nvidia"
  create_namespace = true
  repository       = "https://helm.ngc.nvidia.com/nvidia"
  chart            = "gpu-operator"
  wait             = false
  wait_for_jobs    = false
  version          = "v25.3.4"
  max_history      = 2
  values = [
    yamlencode({
      cdi = {
        enabled = true
        default = true
      }
      # Operator automatically appends -<osrelease> to end of tag. E.g. :<version>-fedora42
      driver = {
        kernelModuleType = "open"
        repository       = join("/", slice(split("/", split(":", local.container_images.nvidia_driver)[0]), 0, 2))
        image            = split("/", split(":", local.container_images.nvidia_driver)[0])[2]
        version          = join("-", slice(split("-", split(":", local.container_images.nvidia_driver)[1]), 0, length(split("-", split(":", local.container_images.nvidia_driver)[1])) - 1))
        upgradePolicy = {
          gpuPodDeletion = {
            force          = true
            deleteEmptyDir = true
          }
        }
      }
      toolkit = {
        enabled = true
      }
      devicePlugin = {
        enabled = true
      }
      dcgmExporter = {
        enabled = false
      }
      migManager = {
        enabled = false
      }
      vgpuDeviceManager = {
        enabled = false
      }
      vfioManager = {
        enabled = false
      }
    })
  ]
  depends_on = [
    kubernetes_labels.labels,
  ]
}

resource "helm_release" "amd-gpu" {
  name             = "amd-gpu"
  namespace        = "amd"
  create_namespace = true
  repository       = "https://rocm.github.io/k8s-device-plugin/"
  chart            = "amd-gpu"
  wait             = false
  wait_for_jobs    = false
  version          = "0.20.0"
  values = [
    yamlencode({
      nfd = {
        enabled = false
      }
      labeller = {
        enabled = false
      }
    })
  ]
  depends_on = [
    kubernetes_labels.labels,
  ]
}

# all modules

resource "helm_release" "wrapper" {
  for_each = {
    for m in local.modules_enabled :
    m.chart.name => m.chart
  }
  chart            = "../helm-wrapper"
  name             = each.key
  namespace        = each.value.namespace
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  max_history      = 2
  values = [
    yamlencode({
      manifests = values(each.value.manifests)
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
  ]
}

# cloudflare tunnel #
/*
resource "helm_release" "cloudflare-tunnel" {
  name          = "cloudflare-tunnel"
  namespace     = "default"
  repository    = "https://cloudflare.github.io/helm-charts/"
  chart         = "cloudflare-tunnel"
  wait          = false
  wait_for_jobs = false
  version       = "0.3.2"
  max_history = 2
  values = [
    yamlencode({
      cloudflare = {
        account    = data.terraform_remote_state.sr.outputs.cloudflare_tunnels.public.account_id
        tunnelName = data.terraform_remote_state.sr.outputs.cloudflare_tunnels.public.name
        tunnelId   = data.terraform_remote_state.sr.outputs.cloudflare_tunnels.public.id
        secret     = data.terraform_remote_state.sr.outputs.cloudflare_tunnels.public.secret
        ingress = [
          {
            hostname = "*.${local.domains.public}"
            service  = "https://${local.kubernetes_services.ingress_nginx_external.endpoint}"
          },
        ]
      }
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
  ]
}
*/