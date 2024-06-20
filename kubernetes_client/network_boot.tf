module "kea" {
  source  = "./modules/kea"
  name    = "kea"
  release = "0.1.20"
  images = {
    kea   = local.container_images.kea
    tftpd = local.container_images.tftpd
  }
  affinity = {
    nodeAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = {
        nodeSelectorTerms = [
          {
            matchExpressions = [
              {
                key      = "kea"
                operator = "Exists"
              },
            ]
          },
        ]
      }
    }
  }
  service_ips = [
    local.services.cluster_kea_primary.ip,
    local.services.cluster_kea_secondary.ip,
  ]
  ports = {
    kea_peer = local.host_ports.kea_peer
    tftpd    = local.host_ports.tftpd
  }
  ipxe_boot_path  = "/ipxe.efi"
  ipxe_script_url = "http://${local.services.matchbox.ip}:${local.service_ports.matchbox}/boot.ipxe"
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
      domain_search = [
        local.domains.public,
        local.domains.kubernetes,
      ]
      mtu = lookup(network, "mtu", 1500)
      pools = [
        cidrsubnet(network.prefix, 1, 1),
      ]
    } if lookup(network, "enable_dhcp_server", false)
  ]
}

module "matchbox" {
  source    = "./modules/matchbox"
  name      = local.kubernetes_services.matchbox.name
  namespace = local.kubernetes_services.matchbox.namespace
  release   = "0.2.16"
  replicas  = 3
  images = {
    matchbox  = local.container_images.matchbox
    syncthing = local.container_images.syncthing
  }
  ports = {
    matchbox     = local.service_ports.matchbox
    matchbox_api = local.service_ports.matchbox_api
  }
  service_ip               = local.services.matchbox.ip
  service_hostname         = local.kubernetes_ingress_endpoints.matchbox
  ca                       = data.terraform_remote_state.sr.outputs.matchbox.ca
  cluster_service_endpoint = local.kubernetes_services.matchbox.fqdn
}
