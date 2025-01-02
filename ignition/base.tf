module "base" {
  for_each = local.members.base
  source   = "./modules/base"

  ignition_version = local.ignition_version
  hostname         = each.value.hostname
  users = [
    for user_key in each.value.users :
    merge(local.users, {
      for type, user in local.users :
      type => merge(
        user,
        lookup(var.users, type, {}),
      )
    })[user_key]
  ]
}

module "systemd-networkd" {
  for_each = local.members.systemd-networkd
  source   = "./modules/systemd_networkd"

  ignition_version    = local.ignition_version
  fw_mark             = local.fw_marks.accept
  host_netnum         = each.value.netnum
  physical_interfaces = each.value.physical_interfaces
  bridge_interfaces   = each.value.bridge_interfaces
  vlan_interfaces     = each.value.vlan_interfaces
  networks            = each.value.networks
  wlan_networks       = each.value.wlan_networks
  mdns_domain         = local.domains.mdns
}

module "server" {
  for_each = local.members.server
  source   = "./modules/server"

  ignition_version = local.ignition_version
  fw_mark          = local.fw_marks.accept
  # SSH
  key_id = each.value.hostname
  valid_principals = sort(concat([
    for _, network in each.value.networks :
    cidrhost(network.prefix, each.value.netnum)
    if lookup(network, "enable_netnum", false)
    ], [
    for _, domain in local.domains :
    "${each.key}.${domain}"
    ], [
    each.key,
    "127.0.0.1",
  ]))
  ca = data.terraform_remote_state.sr.outputs.ssh.ca
  # HA config
  haproxy_path          = local.ha.haproxy_config_path
  keepalived_path       = local.ha.keepalived_config_path
  bird_path             = local.ha.bird_config_path
  bird_cache_table_name = local.ha.bird_cache_table_name

  bgp_router_id      = cidrhost(each.value.networks.node.prefix, each.value.netnum)
  bgp_node_prefix    = each.value.networks.node.prefix
  bgp_node_as        = local.ha.bgp_node_as
  bgp_service_prefix = each.value.networks.service.prefix
  bgp_service_as     = local.ha.bgp_service_as
  bgp_neighbor_netnums = merge({
    for host_key, host in local.members.gateway :
    host_key => host.netnum if each.key != host_key
    }, {
    for host_key, host in local.members.kubernetes-master :
    host_key => host.netnum if each.key != host_key
  })
  bgp_port = local.host_ports.bgp
}