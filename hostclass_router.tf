locals {
  router_hostclass_config = {
    vrrp_netnum = 2
    dhcp_server_subnet = {
      newbit = 1
      netnum = 1
    }
    hosts = {
      router-0 = merge(local.host_spec.supermicro-server, {
        hostname    = "router-0.${local.domains.internal_mdns}"
        kea_ha_role = "backup"
        tap_interfaces = {
          lan = {
            source_interface_name = "phy0"
            enable_mdns           = true
            enable_netnum         = true
            enable_vrrp_netnum    = true
            enable_dhcp_server    = true
            mtu                   = 9000
          }
          sync = {
            source_interface_name = "phy1-sync"
            enable_netnum         = true
            enable_vrrp_netnum    = true
            mtu                   = 9000
          }
          wan = {
            source_interface_name = "phy2-wan"
            enable_dhcp           = true
            mac                   = "52-54-00-63-6e-b3"
          }
        }
      })
    }
  }
}

# templates #
module "template-router-base" {
  for_each = local.router_hostclass_config.hosts

  source   = "./modules/base"
  hostname = each.value.hostname
  users    = [local.users.admin]
}

module "template-router-server" {
  for_each = local.router_hostclass_config.hosts

  source              = "./modules/server"
  networks            = local.networks
  hardware_interfaces = each.value.hardware_interfaces
  tap_interfaces      = each.value.tap_interfaces
  host_netnum         = each.value.netnum
}

module "template-router-ssh_server" {
  for_each = local.router_hostclass_config.hosts

  source     = "./modules/ssh_server"
  key_id     = each.value.hostname
  user_names = [local.users.admin.name]
  valid_principals = compact(concat([each.value.hostname, "127.0.0.1"], flatten([
    for interface in values(module.template-router-server[each.key].interfaces) :
    try(cidrhost(interface.prefix, each.value.netnum), null)
    if lookup(interface, "enable_netnum", false)
  ])))
  ssh_ca = module.ssh-server-common.ca.ssh
}

# combine and render a single ignition file #
data "ct_config" "router" {
  for_each = local.router_hostclass_config.hosts

  content = <<EOT
---
variant: fcos
version: 1.4.0
EOT
  strict  = true
  snippets = concat(
    module.template-router-base[each.key].ignition_snippets,
    module.template-router-server[each.key].ignition_snippets,
    module.template-router-ssh_server[each.key].ignition_snippets,
  )
}

resource "local_file" "router" {
  for_each = local.router_hostclass_config.hosts

  content  = data.ct_config.router[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}