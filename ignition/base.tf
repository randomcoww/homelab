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

module "ha" {
  for_each = local.members.ha
  source   = "./modules/ha"

  ignition_version = local.ignition_version
  haproxy_path     = local.ha.haproxy_config_path
  keepalived_path  = local.ha.keepalived_config_path
  bird_path        = local.ha.bird_config_path
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

module "network-manager" {
  for_each         = local.members.network-manager
  source           = "./modules/network_manager"
  ignition_version = local.ignition_version
}