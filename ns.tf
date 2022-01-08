locals {
  ns_hostclass_config = {
    vrrp_netnum = 2
    dhcp_server = {
      newbit = 1
      netnum = 1
    }
    hosts = {
      ns-0 = {
        hostname = "ns-0.${local.config.domains.internal_mdns}"
        netnum   = 5
        interfaces = {
          internal = {
            enable_unmanaged = true
          }
          lan = {
            enable_mdns        = true
            mtu                = 9000
            enable_vrrp_netnum = true
            enable_netnum      = true
            enable_dhcp_server = true
          }
        }
        kea_ha_role = "primary"
      }
      ns-1 = {
        hostname = "ns-1.${local.config.domains.internal_mdns}"
        netnum   = 6
        interfaces = {
          internal = {
            enable_unmanaged = true
          }
          lan = {
            enable_mdns        = true
            mtu                = 9000
            enable_vrrp_netnum = true
            enable_netnum      = true
            enable_dhcp_server = true
          }
        }
        kea_ha_role = "secondary"
      }
    }
  }
}

# templates #
module "template-ns-guest_interfaces" {
  for_each = local.ns_hostclass_config.hosts

  source      = "./modules/guest_interfaces"
  networks    = local.config.networks
  host_netnum = each.value.netnum
  interfaces  = each.value.interfaces
}

module "template-ns" {
  for_each = local.ns_hostclass_config.hosts

  source           = "./modules/ns"
  hostname         = each.value.hostname
  user             = local.config.users.admin
  guest_interfaces = module.template-ns-guest_interfaces[each.key].interfaces
  domains          = local.config.domains
  dhcp_server      = local.ns_hostclass_config.dhcp_server
  container_images = local.config.container_images
  netnums = {
    host         = each.value.netnum
    vrrp         = local.ns_hostclass_config.vrrp_netnum
    gateway_vrrp = local.gateway_hostclass_config.vrrp_netnum
  }
  kea_peers = [
    for host in values(local.ns_hostclass_config.hosts) :
    {
      name   = host.hostname
      role   = lookup(host, "kea_ha_role", "backup")
      netnum = host.netnum
    }
  ]
}

module "template-ns-ssh_server" {
  for_each = local.ns_hostclass_config.hosts

  source     = "./modules/ssh_server"
  key_id     = each.value.hostname
  user_names = [local.config.users.admin.name]
  valid_principals = compact(concat([each.value.hostname, "127.0.0.1"], flatten([
    for interface in values(module.template-ns-guest_interfaces[each.key].interfaces) :
    try(cidrhost(interface.prefix, each.value.netnum), null)
  ])))
  ssh_ca = local.config.ca.ssh
}

# combine and render a single ignition file #
data "ct_config" "ns" {
  for_each = local.ns_hostclass_config.hosts

  content = <<EOT
---
variant: fcos
version: 1.4.0
EOT
  strict  = true
  snippets = concat(
    module.template-ns-guest_interfaces[each.key].ignition_snippets,
    module.template-ns[each.key].ignition_snippets,
    module.template-ns-ssh_server[each.key].ignition_snippets,
  )
}

resource "local_file" "ns" {
  for_each = local.ns_hostclass_config.hosts

  content  = data.ct_config.ns[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}