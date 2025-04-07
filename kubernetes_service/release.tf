## Hack to release custom charts as local chart

locals {
  modules_enabled = [
    module.kvm-device-plugin,
    module.nvidia-driver,
    module.kea,
    module.matchbox,
    module.lldap,
    module.authelia,
    module.tailscale,
    module.hostapd,
    module.qrcode-hostapd,
    module.alpaca-db,
    module.webdav-pictures,
    module.webdav-videos,
    module.audioserve,
    module.vaultwarden,
    module.llama-cpp,
    # module.code,
    # module.sunshine-desktop,
    # module.satisfactory-server,
  ]
}

# nginx ingress #

resource "helm_release" "ingress-nginx" {
  for_each = local.ingress_classes

  name             = each.value
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = local.kubernetes_services[each.key].namespace
  create_namespace = true
  wait             = false
  version          = "4.12.1"
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

# nvidia device plugin #

resource "helm_release" "nvidia-device-plugin" {
  name        = "nvidia-device-plugin"
  repository  = "https://nvidia.github.io/k8s-device-plugin"
  chart       = "nvidia-device-plugin"
  namespace   = "kube-system"
  wait        = false
  version     = "0.17.1"
  max_history = 2
  values = [
    yamlencode({
      compatWithCPUManager = true
      priorityClassName    = "system-node-critical"
      nvidiaDriverRoot     = "/run/nvidia/driver"
      cdi = {
        nvidiaHookPath = "/usr/bin/nvidia-ctk"
      }
      gfd = {
        enabled = true
      }
      config = {
        # map = {
        #   default = yamlencode({
        #     version = "v1"
        #     sharing = {
        #       mps = {
        #         renameByDefault = true
        #         resources = [
        #           {
        #             name     = "nvidia.com/gpu"
        #             replicas = 2
        #           },
        #         ]
        #       }
        #     }
        #   })
        # }
      }
    }),
  ]
}

# cloudflare tunnel #
/*
resource "helm_release" "cloudflare-tunnel" {
  name        = "cloudflare-tunnel"
  namespace   = "default"
  repository  = "https://cloudflare.github.io/helm-charts/"
  chart       = "cloudflare-tunnel"
  wait        = false
  version     = "0.3.2"
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
# kured #

resource "helm_release" "kured" {
  name             = "kured"
  namespace        = "monitoring"
  create_namespace = true
  repository       = "https://kubereboot.github.io/charts"
  chart            = "kured"
  wait             = false
  version          = "5.6.1"
  max_history      = 2
  values = [
    yamlencode({
      configuration = {
        # promethues chart creates service name <name>-server
        prometheusUrl            = "http://${local.kubernetes_services.prometheus.name}-server.${local.kubernetes_services.prometheus.namespace}:${local.service_ports.prometheus}"
        period                   = "2m"
        metricsPort              = local.service_ports.metrics
        forceReboot              = true
        drainTimeout             = "6m"
        skipWaitForDeleteTimeout = 300
      }
      service = {
        create = true
        port   = local.service_ports.metrics
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = tostring(local.service_ports.metrics)
        }
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
  wait             = false
  timeout          = 300
  max_history      = 2
  values = [
    yamlencode({
      manifests = values(each.value.manifests)
    }),
  ]
}