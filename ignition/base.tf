module "base" {
  for_each = local.members.base
  source   = "./modules/base"

  butane_version = local.butane_version
  hostname       = each.value.hostname
}

module "systemd-networkd" {
  for_each = local.members.systemd-networkd
  source   = "./modules/systemd_networkd"

  butane_version      = local.butane_version
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

  butane_version = local.butane_version
  fw_mark        = local.fw_marks.accept
  # SSH
  user   = local.users.ssh
  key_id = each.value.hostname
  valid_principals = sort(concat([
    for _, network in each.value.networks :
    cidrhost(network.prefix, each.value.netnum)
    if lookup(network, "enable_netnum", false)
    ], [
    local.domains.mdns,
    local.domains.kubernetes,
    each.key,
    "127.0.0.1",
  ]))
  ca = data.terraform_remote_state.sr.outputs.ssh.ca
  # HA config
  keepalived_path       = local.ha.keepalived_config_path
  haproxy_path          = local.ha.haproxy_config_path
  bird_path             = local.ha.bird_config_path
  bird_cache_table_name = local.ha.bird_cache_table_name
  bgp_router_id         = cidrhost(values(each.value.networks)[0].prefix, each.value.netnum)
  bgp_port              = local.host_ports.bgp
}

# dev client
module "client" {
  for_each = local.members.client
  source   = "./modules/client"

  butane_version = local.butane_version
  user           = local.users.client
}