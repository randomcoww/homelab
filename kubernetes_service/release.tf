## Hack to release custom charts as local chart

locals {
  modules_enabled = [
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
    # module.code-server,
    module.llama-cpp,
    # module.sunshine-desktop,
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
  wait             = true
  wait_for_jobs    = true
  timeout          = local.kubernetes.helm_release_wait
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
}

# Nvidia GPU

resource "helm_release" "nvidia-gpu-oprerator" {
  name             = "gpu-operator"
  namespace        = "nvidia"
  create_namespace = true
  repository       = "https://helm.ngc.nvidia.com/nvidia"
  chart            = "gpu-operator"
  wait             = true
  wait_for_jobs    = true
  timeout          = local.kubernetes.helm_release_wait
  version          = "v25.3.3"
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
}

resource "helm_release" "amd-gpu" {
  name             = "amd-gpu"
  namespace        = "amd"
  create_namespace = true
  repository       = "https://rocm.github.io/k8s-device-plugin/"
  chart            = "amd-gpu"
  wait             = true
  wait_for_jobs    = true
  timeout          = local.kubernetes.helm_release_wait
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
  wait             = true
  wait_for_jobs    = true
  timeout          = local.kubernetes.helm_release_wait
  max_history      = 2
  values = [
    yamlencode({
      manifests = values(each.value.manifests)
    }),
  ]
}

# cloudflare tunnel #
/*
resource "helm_release" "cloudflare-tunnel" {
  name          = "cloudflare-tunnel"
  namespace     = "default"
  repository    = "https://cloudflare.github.io/helm-charts/"
  chart         = "cloudflare-tunnel"
  wait          = true
  wait_for_jobs = true
  timeout       = local.kubernetes.helm_release_wait
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
}
*/