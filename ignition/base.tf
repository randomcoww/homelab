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

module "vrrp" {
  for_each = local.members.vrrp
  source   = "./modules/vrrp"

  ignition_version = local.ignition_version
  haproxy_path     = local.vrrp.haproxy_config_path
  keepalived_path  = local.vrrp.keepalived_config_path
}

module "systemd-networkd" {
  for_each = local.members.systemd-networkd
  source   = "./modules/systemd_networkd"

  ignition_version    = local.ignition_version
  host_netnum         = each.value.netnum
  physical_interfaces = lookup(each.value, "physical_interfaces", {})
  bridge_interfaces   = lookup(each.value, "bridge_interfaces", {})
  wlan_interfaces     = lookup(each.value, "wlan_interfaces", {})
  tap_interfaces      = lookup(each.value, "tap_interfaces", {})
}

module "network-manager" {
  for_each         = local.members.network-manager
  source           = "./modules/network_manager"
  ignition_version = local.ignition_version
}