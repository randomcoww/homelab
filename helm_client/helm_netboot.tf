# kea #

resource "helm_release" "kea" {
  name  = "kea"
  chart = "${path.module}/output/charts/kea"
  wait  = false
}

# module "kea-config" {
#   source        = "./modules/kea_config"
#   resource_name = "kea"
#   service_ips = [
#     local.services.cluster_kea_primary.ip, local.services.cluster_kea_secondary.ip
#   ]
#   shared_data_path = "/var/lib/kea"
#   kea_peer_port    = local.ports.kea_peer
#   ipxe_boot_path   = "/ipxe.efi"
#   ipxe_script_url  = "http://${local.services.matchbox.ip}:${local.ports.matchbox}/boot.ipxe"
#   cluster_domain   = local.domains.kubernetes
#   namespace        = "default"
#   networks = [
#     for _, network in local.networks :
#     {
#       prefix = network.prefix
#       routers = [
#         local.services.gateway.ip,
#       ]
#       domain_name_servers = [
#         local.services.external_dns.ip,
#       ]
#       domain_search = [
#         local.domains.internal,
#       ]
#       mtu = network.mtu
#       pools = [
#         cidrsubnet(network.prefix, 1, 1),
#       ]
#     } if lookup(network, "enable_dhcp_server", false)
#   ]
# }

# resource "helm_release" "kea" {
#   name       = "kea"
#   namespace  = "default"
#   repository = "https://randomcoww.github.io/repos/helm/"
#   chart      = "kea"
#   wait       = false
#   version    = "0.1.18"
#   values = [
#     yamlencode({
#       images = {
#         kea   = local.container_images.kea
#         tftpd = local.container_images.tftpd
#       }
#       peers = [
#         for _, peer in module.kea-config.config :
#         {
#           serviceIP       = peer.service_ip
#           podName         = peer.pod_name
#           dhcp4Config     = peer.dhcp4_config
#           ctrlAgentConfig = peer.ctrl_agent_config
#         }
#       ]
#       sharedDataPath = "/var/lib/kea"
#       StatefulSet = {
#         replicaCount = length(module.kea-config.config)
#       }
#       affinity = {
#         nodeAffinity = {
#           requiredDuringSchedulingIgnoredDuringExecution = {
#             nodeSelectorTerms = [
#               {
#                 matchExpressions = [
#                   {
#                     key      = "kea"
#                     operator = "Exists"
#                   },
#                 ]
#               },
#             ]
#           }
#         }
#         podAntiAffinity = {
#           requiredDuringSchedulingIgnoredDuringExecution = [
#             {
#               labelSelector = {
#                 matchExpressions = [
#                   {
#                     key      = "app"
#                     operator = "In"
#                     values = [
#                       "kea",
#                     ]
#                   },
#                 ]
#               }
#               topologyKey = "kubernetes.io/hostname"
#             },
#           ]
#         }
#       }
#       ports = {
#         keaPeer = local.ports.kea_peer
#         tftpd   = local.ports.tftpd
#       }
#       peerService = {
#         port = local.ports.kea_peer
#       }
#     }),
#   ]
# }

# matchbox with data sync #

resource "helm_release" "matchbox" {
  name  = "matchbox"
  chart = "${path.module}/output/charts/matchbox"
  wait  = false
}