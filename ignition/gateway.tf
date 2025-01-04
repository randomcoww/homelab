
module "gateway" {
  for_each = local.members.gateway
  source   = "./modules/gateway"

  ignition_version = local.ignition_version
  fw_mark          = local.fw_marks.accept
  host_netnum      = each.value.netnum
  conntrackd_ignore_prefixes = sort(
    setsubtract(compact([
      for _, network in local.networks :
      try(network.prefix, "")
    ]), [local.services.gateway.network.prefix])
  )

  wan_interface_name    = each.value.networks.wan.interface
  sync_interface_name   = each.value.networks.sync.interface
  lan_interface_name    = each.value.networks[local.services.gateway.network.name].interface
  sync_prefix           = each.value.networks.sync.prefix
  lan_prefix            = each.value.networks[local.services.gateway.network.name].prefix
  lan_gateway_ip        = local.services.gateway.ip
  virtual_router_id     = 13
  keepalived_path       = local.ha.keepalived_config_path
  bird_path             = local.ha.bird_config_path
  bird_cache_table_name = local.ha.bird_cache_table_name
  bgp_port              = local.host_ports.bgp
  bgp_prefix            = each.value.networks.service.prefix
  bgp_as                = local.ha.bgp_as_gateway
  bgp_internal_neighbor_netnums = {
    for host_key, host in local.members.gateway :
    host_key => host.netnum if each.key != host_key
  }
  bgp_external_neighbor_netnums = {
    for host_key, host in local.members.kubernetes-master :
    host_key => host.netnum if each.key != host_key
  }
}

# Configure upstream DNS for gateways

module "upstream-dns" {
  for_each         = local.members.upstream-dns
  source           = "./modules/upstream_dns"
  ignition_version = local.ignition_version
  upstream_dns     = local.upstream_dns
}