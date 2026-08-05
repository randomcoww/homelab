module "gateway" {
  for_each = local.members.gateway
  source   = "./modules/gateway"

  butane_version        = local.butane_version
  fw_mark               = local.fw_marks.accept
  host_netnum           = each.value.netnum
  wan_network_config    = each.value.networks.wan
  vrrp_network_config   = each.value.networks.lan
  bird_path             = local.bird_config_path
  bird_cache_table_name = local.bird_cache_table_name
  bgp_port              = local.host_ports.bgp
  bgp_as                = local.bgp.host_as
  bgp_as_peer           = local.bgp.cluster_as
  bgp_neighbor_netnums = {
    for host_key, host in local.members.gateway :
    host_key => host.netnum if each.key != host_key
  }
  node_prefix     = each.value.networks.node.prefix
  service_prefix  = each.value.networks.service.prefix
  keepalived_path = local.keepalived_config_path
}