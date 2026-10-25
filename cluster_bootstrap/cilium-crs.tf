resource "helm_release" "cilium-crs" {
  chart            = "../helm-wrapper"
  name             = "${local.services.cilium.name}-crs"
  namespace        = local.services.cilium.namespace
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  max_history      = 2
  values = [
    yamlencode({
      manifests = [
        for _, m in [
          {
            apiVersion = "v1"
            kind       = "Secret"
            metadata = {
              name = "${local.services.cilium.name}-bgp-auth"
            }
            stringData = {
              password = data.terraform_remote_state.host.outputs.bgp_password
            }
          },
          {
            apiVersion = "cilium.io/v2"
            kind       = "CiliumBGPPeerConfig"
            metadata = {
              name = "cilium-peer"
            }
            spec = {
              ebgpMultihop  = 1
              authSecretRef = "${local.services.cilium.name}-bgp-auth"
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
        ] :
        yamlencode(m)
      ]
    }),
  ]
  depends_on = [
    kubernetes_node_taint.taints,
    helm_release.cilium,
  ]
}