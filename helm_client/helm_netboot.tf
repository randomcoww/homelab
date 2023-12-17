# kea #

module "kea-config" {
  source        = "./modules/kea_config"
  resource_name = "kea"
  service_ips = [
    local.services.cluster_kea_primary.ip, local.services.cluster_kea_secondary.ip
  ]
  shared_data_path = "/var/lib/kea"
  kea_peer_port    = local.ports.kea_peer
  ipxe_boot_path   = "/ipxe.efi"
  ipxe_script_url  = "http://${local.services.matchbox.ip}:${local.ports.matchbox}/boot.ipxe"
  cluster_domain   = local.domains.kubernetes
  namespace        = "default"
  networks = [
    for _, network in local.networks :
    {
      prefix = network.prefix
      routers = [
        local.services.gateway.ip,
      ]
      domain_name_servers = [
        local.services.external_dns.ip,
      ]
      mtu = network.mtu
      pools = [
        cidrsubnet(network.prefix, 1, 1),
      ]
    } if lookup(network, "enable_dhcp_server", false)
  ]
}

resource "helm_release" "kea" {
  name       = "kea"
  namespace  = "default"
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "kea"
  wait       = false
  version    = "0.1.18"
  values = [
    yamlencode({
      images = {
        kea   = local.container_images.kea
        tftpd = local.container_images.tftpd
      }
      peers = [
        for _, peer in module.kea-config.config :
        {
          serviceIP       = peer.service_ip
          podName         = peer.pod_name
          dhcp4Config     = peer.dhcp4_config
          ctrlAgentConfig = peer.ctrl_agent_config
        }
      ]
      sharedDataPath = "/var/lib/kea"
      StatefulSet = {
        replicaCount = length(module.kea-config.config)
      }
      affinity = {
        podAntiAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = [
            {
              labelSelector = {
                matchExpressions = [
                  {
                    key      = "app"
                    operator = "In"
                    values = [
                      "kea",
                    ]
                  },
                ]
              }
              topologyKey = "kubernetes.io/hostname"
            },
          ]
        }
      }
      ports = {
        keaPeer = local.ports.kea_peer
        tftpd   = local.ports.pxe_tftp
      }
      peerService = {
        port = local.ports.kea_peer
      }
    }),
  ]
}

# matchbox with data sync #

module "matchbox-syncthing" {
  source              = "./modules/syncthing_config"
  replica_count       = 3
  resource_name       = "matchbox"
  resource_namespace  = "default"
  service_name        = "matchbox-sync"
  sync_data_paths     = ["/var/tmp/matchbox"]
  syncthing_peer_port = 22000
}

resource "helm_release" "matchbox" {
  name       = "matchbox"
  namespace  = "default"
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "matchbox"
  wait       = false
  version    = "0.2.14"
  values = [
    yamlencode({
      images = {
        matchbox  = local.container_images.matchbox
        syncthing = local.container_images.syncthing
      }
      peers = [
        for _, peer in module.matchbox-syncthing.peers :
        {
          podName       = peer.pod_name
          syncthingCert = chomp(peer.cert)
          syncthingKey  = chomp(peer.key)
        }
      ]
      syncthingConfig = module.matchbox-syncthing.config
      matchboxSecret = {
        ca   = chomp(data.terraform_remote_state.sr.outputs.matchbox_ca.cert_pem)
        cert = chomp(tls_locally_signed_cert.matchbox.cert_pem)
        key  = chomp(tls_private_key.matchbox.private_key_pem)
      }
      sharedDataPath = "/var/tmp/matchbox"
      StatefulSet = {
        replicaCount = length(module.matchbox-syncthing.peers)
      }
      affinity = {
        podAntiAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = [
            {
              labelSelector = {
                matchExpressions = [
                  {
                    key      = "app"
                    operator = "In"
                    values = [
                      "matchbox",
                    ]
                  },
                ]
              }
              topologyKey = "kubernetes.io/hostname"
            },
          ]
        }
      }
      ports = {
        matchbox    = local.ports.matchbox
        matchboxAPI = local.ports.matchbox_api
      }
      syncService = {
        port = 22000
      }
      apiService = {
        type = "LoadBalancer"
        port = local.ports.matchbox_api
        externalIPs = [
          local.services.matchbox.ip,
        ]
      }
      service = {
        type = "LoadBalancer"
        port = local.ports.matchbox
        externalIPs = [
          local.services.matchbox.ip,
        ]
        annotations = {
          "external-dns.alpha.kubernetes.io/hostname" = local.kubernetes_ingress_endpoints.matchbox
        }
      }
    }),
  ]
}