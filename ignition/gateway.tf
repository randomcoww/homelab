
module "gateway" {
  for_each = local.members.gateway
  source   = "./modules/gateway"

  ignition_version      = local.ignition_version
  fw_mark               = local.fw_marks.accept
  host_netnum           = each.value.netnum
  wan_interface_name    = each.value.networks.wan.interface
  bird_path             = local.ha.bird_config_path
  bird_cache_table_name = local.ha.bird_cache_table_name
  bgp_port              = local.host_ports.bgp
  bgp_as                = local.ha.bgp_as_gateway
  bgp_node_prefix       = each.value.networks.node.prefix
  bgp_service_prefix    = each.value.networks.service.prefix
  bgp_neighbor_netnums = {
    for host_key, host in local.members.gateway :
    host_key => host.netnum if each.key != host_key
  }
  sync_interface_name = each.value.networks.sync.interface
  conntrackd_ip       = cidrhost(each.value.networks.sync.prefix, each.value.netnum)
  conntrackd_ignore_ipv4 = concat([
    local.services.gateway.ip,
    local.networks.kubernetes_pod.prefix,
    local.networks.kubernetes_service.prefix,
    ], flatten([
      for _, host in local.members.gateway :
      [
        for _, network in host.networks :
        cidrhost(network.prefix, host.netnum)
        if lookup(network, "enable_netnum", false)
      ]
  ]))
  keepalived_path           = local.ha.keepalived_config_path
  keepalived_interface_name = each.value.networks[local.services.gateway.network.name].interface
  keepalived_vip            = local.services.gateway.ip
  keepalived_prefix         = each.value.networks[local.services.gateway.network.name].prefix
  keepalived_router_id      = 13
}

# Configure upstream DNS for gateways

module "upstream-dns" {
  for_each         = local.members.upstream-dns
  source           = "./modules/upstream_dns"
  ignition_version = local.ignition_version
  upstream_dns     = local.upstream_dns
}