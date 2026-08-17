module "cilium-cert-issuer-secret" {
  source    = "../modules/secret"
  name      = "${local.services.cilium.name}-cert-manager-crs"
  namespace = local.services.cilium.namespace
  app       = "${local.services.cilium.name}-cert-manager-crs"
  release   = "0.1.0"
  data = {
    "tls.crt" = data.terraform_remote_state.host.outputs.internal_ca.cert_pem
    "tls.key" = data.terraform_remote_state.host.outputs.internal_ca.private_key_pem
  }
}

resource "helm_release" "cilium-cert-manager-crs" {
  chart            = "../helm-wrapper"
  name             = "${local.services.cilium.name}-cert-manager-crs"
  namespace        = local.services.cilium.namespace
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  max_history      = 2
  values = [
    yamlencode({
      manifests = concat([
        for _, m in [
          {
            apiVersion = "cert-manager.io/v1"
            kind       = "Issuer"
            metadata = {
              name = local.services.cilium.name
            }
            spec = {
              ca = {
                secretName = module.cilium-cert-issuer-secret.name
              }
            }
          },
        ] :
        yamlencode(m)
        ], [
        module.cilium-cert-issuer-secret.manifest,
      ])
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
    helm_release.cert-manager-crds,
  ]
}

resource "helm_release" "cilium" {
  name             = local.services.cilium.name
  namespace        = local.services.cilium.namespace
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
        enabled = true
        metrics = {
          enabled = [
            "dns:query;ignoreAAAA",
            "drop",
            "tcp",
            "flow",
            "icmp",
            "http",
          ]
          serviceMonitor = {
            enabled = true
          }
        }
        peerService = {
          clusterDomain = local.domains.kubernetes
        }
        tls = {
          enabled = true
          auto = {
            enabled = true
            method  = "certmanager"
            certManagerIssuerRef = {
              group = "cert-manager.io"
              kind  = "Issuer"
              name  = local.services.cilium.name
            }
          }
        }
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
      k8sServiceHost       = local.networks.service.vips.apiserver
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