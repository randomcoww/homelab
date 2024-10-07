
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

  wan_interface_name  = each.value.networks.wan.interface
  sync_interface_name = each.value.networks.sync.interface
  lan_interface_name  = each.value.networks[local.services.gateway.network.name].interface
  sync_prefix         = each.value.networks.sync.prefix
  lan_prefix          = each.value.networks[local.services.gateway.network.name].prefix
  lan_gateway_ip      = local.services.gateway.ip
  virtual_router_id   = 13
  keepalived_path     = local.vrrp.keepalived_config_path
  # from lan to apiservers
  static_routes = [
    {
      destination_prefix = "${local.services.apiserver.ip}/32"
      table_id           = 260
      priority           = 32600
      routes = [
        for _, m in local.members.kubernetes-master :
        {
          ip        = cidrhost(each.value.networks[local.services.apiserver.network.name].prefix, m.netnum)
          interface = each.value.networks[local.services.apiserver.network.name].interface
          weight    = 1
        }
      ]
    },
  ]
}

# Configure upstream DNS for gateways

module "upstream-dns" {
  for_each         = local.members.upstream-dns
  source           = "./modules/upstream_dns"
  ignition_version = local.ignition_version
  upstream_dns     = local.upstream_dns
}