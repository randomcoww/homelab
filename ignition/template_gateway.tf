
module "gateway" {
  for_each = local.members.gateway
  source   = "./modules/gateway"

  butane_version = local.butane_version
  fw_mark        = local.fw_marks.accept
  host_netnum    = each.value.netnum
  wan_interface_names = [
    each.value.networks.wan.interface,
    each.value.networks.backup.interface,
  ]
  bird_path             = local.ha.bird_config_path
  bird_cache_table_name = local.ha.bird_cache_table_name
  bgp_port              = local.host_ports.bgp
  bgp_as                = local.ha.bgp_as
  bgp_neighbor_netnums = {
    for host_key, host in local.members.gateway :
    host_key => host.netnum if each.key != host_key
  }
  node_prefix         = each.value.networks.node.prefix
  service_prefix      = each.value.networks.service.prefix
  sync_prefix         = each.value.networks.sync.prefix
  sync_interface_name = each.value.networks.sync.interface
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
  keepalived_router_id      = 13
  keepalived_path           = local.ha.keepalived_config_path
  keepalived_interface_name = each.value.networks[local.services.gateway.network.name].interface
  # Use VIP with network netmask to intentionally create a prefix route on main table
  keepalived_vip = "${local.services.gateway.ip}/${each.value.networks[local.services.gateway.network.name].cidr}"
}

# Configure upstream DNS for gateways

module "upstream-dns" {
  for_each       = local.members.upstream-dns
  source         = "./modules/upstream_dns"
  butane_version = local.butane_version
  upstream_dns   = local.upstream_dns
}