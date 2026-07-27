resource "helm_release" "cilium" {
  name             = local.endpoints.cilium.name
  namespace        = local.endpoints.cilium.namespace
  repository       = "https://helm.cilium.io"
  chart            = "cilium"
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  version          = "1.20.0-rc.1" # TODO: move to release version
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
        "phy-service", # direct
        "phy-node",    # router (cp nodes)
        "phy-wan",     # internet (gw nodes)
      ])
      kubeProxyReplacement = true
      k8sServiceHost       = local.vips.apiserver.ip
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

resource "helm_release" "cilium-crs" {
  chart            = "../helm-wrapper"
  name             = "${local.endpoints.cilium.name}-crs"
  namespace        = local.endpoints.cilium.namespace
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  max_history      = 2
  values = [
    yamlencode({
      manifests = [
        for _, m in [
          {
            apiVersion = "cilium.io/v2"
            kind       = "CiliumBGPPeerConfig"
            metadata = {
              name = "cilium-peer"
            }
            spec = {
              ebgpMultihop = 4
              gracefulRestart = {
                enabled = true
              }
              transport = {
                peerPort = local.host_ports.bgp
              }
              families = [
                {
                  afi  = "ipv4"
                  safi = "unicast"
                  advertisements = {
                    matchLabels = {
                    }
                  }
                },
              ]
            }
          },
          {
            apiVersion = "cilium.io/v2"
            kind       = "CiliumBGPClusterConfig"
            metadata = {
              name = "cilium-bgp"
            }
            spec = {
              nodeSelector = {
                matchLabels = {}
              }
              bgpInstances = [
                {
                  name     = "instance-${local.ha.bgp_as}"
                  localASN = local.ha.bgp_as_cluster
                  peers = [
                    for k, host in local.members.gateway :
                    {
                      name        = "peer-${k}"
                      peerASN     = local.ha.bgp_as
                      peerAddress = cidrhost(local.networks.service.prefix, host.netnum)
                      peerConfigRef = {
                        name = "cilium-peer"
                      }
                    }
                  ]
                },
              ]
            }
          },
          {
            apiVersion = "cilium.io/v2"
            kind       = "CiliumBGPAdvertisement"
            metadata = {
              name = "bgp-advertisements"
            }
            spec = {
              advertisements = [
                {
                  advertisementType = "Service"
                  service = {
                    addresses = [
                      "ExternalIP",
                      "LoadBalancerIP",
                    ]
                  }
                  selector = {
                    matchLabels = {
                    }
                  }
                },
              ]
            }
          },
        ] :
        yamlencode(m)
      ]
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
    helm_release.cilium,
  ]
}