module "apiserver-lb-service" {
  source    = "../modules/service"
  name      = local.endpoints.apiserver_lb.name
  namespace = local.endpoints.apiserver_lb.namespace
  app       = local.endpoints.apiserver_lb.name
  release   = "0.1.0"
  annotations = {
    "lbipam.cilium.io/ips" = local.endpoints.apiserver_lb.service_ip
  }
  selector = {
    k8s-app = local.endpoints.apiserver_lb.name
  }
  spec = {
    type                  = "LoadBalancer"
    externalTrafficPolicy = "Local"
    ports = [
      {
        name       = "https"
        port       = local.host_ports.apiserver
        protocol   = "TCP"
        targetPort = local.host_ports.apiserver
      },
    ]
  }
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
      manifests = concat([
        for _, m in [
          {
            apiVersion = "cilium.io/v2"
            kind       = "CiliumBGPPeerConfig"
            metadata = {
              name = "cilium-peer"
            }
            spec = {
              ebgpMultihop = 1
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
                matchLabels = {
                  # "node-role.kubernetes.io/control-plane" = "true"
                }
              }
              bgpInstances = [
                {
                  name     = "instance-${local.bgp.host_as}"
                  localASN = local.bgp.cluster_as
                  peers = [
                    for k, host in local.members.gateway :
                    {
                      name        = "peer-${k}"
                      peerASN     = local.bgp.host_as
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

          # cilium loadbalancer for apiserver
          {
            apiVersion = "cilium.io/v2"
            kind       = "CiliumLoadBalancerIPPool"
            metadata = {
              name = "${local.endpoints.apiserver_lb.namespace}-${local.endpoints.apiserver_lb.name}"
            }
            spec = {
              blocks = [
                {
                  cidr = "${local.endpoints.apiserver_lb.service_ip}/32"
                },
              ]
              serviceSelector = {
                matchLabels = {
                  "io.kubernetes.service.namespace" = local.endpoints.apiserver_lb.namespace
                  "io.kubernetes.service.name"      = local.endpoints.apiserver_lb.name
                }
              }
            }
          },
        ] :
        yamlencode(m)
        ], [

        # cilium loadbalancer for apiserver
        module.apiserver-lb-service.manifest,
      ])
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
    helm_release.cilium,
  ]
}