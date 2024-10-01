
module "gateway" {
  for_each = local.members.gateway
  source   = "./modules/gateway"

  ignition_version = local.ignition_version
  host_netnum      = each.value.netnum
  conntrackd_ignore_prefixes = sort(
    setsubtract(compact([
      for _, network in local.networks :
      try(network.prefix, "")
    ]), [local.services.gateway.network.prefix])
  )

  wan_interface_name  = each.value.networks.wan.interface
  sync_interface_name = each.value.networks.sync.interface
  lan_interface_name  = each.value.networks[local.services.gateway.network.name].interface
  lan_prefix          = local.services.gateway.network.prefix
  sync_prefix         = local.networks.sync.prefix
  lan_gateway_ip      = local.services.gateway.ip
  network_boot_prefix = local.networks.priv.prefix
  virtual_router_id   = 13
  keepalived_path     = local.vrrp.keepalived_config_path
}

# Configure upstream DNS for gateways

module "upstream-dns" {
  for_each         = local.members.upstream-dns
  source           = "./modules/upstream_dns"
  ignition_version = local.ignition_version
  upstream_dns     = local.upstream_dns
}