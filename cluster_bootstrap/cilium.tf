resource "helm_release" "cilium" {
  name             = local.endpoints.cilium.name
  namespace        = local.endpoints.cilium.namespace
  repository       = "https://helm.cilium.io"
  chart            = "cilium"
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  version          = "1.20.0"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      routingMode          = "native"
      autoDirectNodeRoutes = true
      bpf = {
        masquerade = true
      }
      cni = {
        binPath  = local.kubernetes.cni_bin_path
        confPath = local.kubernetes.cni_config_path
      }
      gatewayAPI = {
        enabled = true
      }
      bgpControlPlane = {
        enabled = true
      }
      hubble = {
        enabled = false
      }
      ipMasqAgent = {
        enabled = true
      }
      ipv4 = {
        enabled = true
      }
      ipv4NativeRoutingCIDR = local.networks.kubernetes_pod.prefix
      enableIPv4Masquerade  = true
      envoy = {
        prometheus = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
      }
      operator = {
        prometheus = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
      }
      prometheus = {
        enabled = true
        serviceMonitor = {
          enabled = true
        }
      }
      devices = join(",", [
        local.networks.service.interface, # direct
        local.networks.node.interface,    # router (cp nodes)
        local.networks.wan.interface,     # internet (gw nodes)
      ])
      kubeProxyReplacement = true
      k8sServiceHost       = local.endpoints.apiserver-lb.service_ip
      k8sServicePort       = local.host_ports.apiserver
      ipam = {
        mode = "kubernetes"
        operator = {
          clusterPoolIPv4PodCIDRList = [
            local.networks.kubernetes_pod.prefix,
          ]
        }
      }
      priorityClassName = "system-node-critical"
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
    helm_release.cert-manager-crds,
  ]
}