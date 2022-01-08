locals {
  ns = {
    vrrp_netnum = 2
    dhcp_server = {
      newbit = 1
      netnum = 1
    }
    hosts = {
      ns-0 = {
        hostname = "ns-0.${local.common.domains.internal_mdns}"
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
        hostname = "ns-1.${local.common.domains.internal_mdns}"
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
  for_each = local.ns.hosts

  source                       = "./modules/guest_interfaces"
  networks                     = local.common.networks
  host_netnum                  = each.value.netnum
  interfaces                   = each.value.interfaces
  guest_interface_device_order = local.common.guest_interface_device_order
}

module "template-ns" {
  for_each = local.ns.hosts

  source           = "./modules/ns"
  hostname         = each.value.hostname
  user             = local.common.users.admin
  guest_interfaces = module.template-ns-guest_interfaces[each.key].interfaces
  domains          = local.common.domains
  dhcp_server      = local.ns.dhcp_server
  ssh_ca           = local.common.ca.ssh
  container_images = local.common.container_images
  netnums = {
    host         = each.value.netnum
    vrrp         = local.ns.vrrp_netnum
    gateway_vrrp = local.gateways.vrrp_netnum
  }
  kea_peers = [
    for host in values(local.ns.hosts) :
    {
      name   = host.hostname
      role   = lookup(host, "kea_ha_role", "backup")
      netnum = host.netnum
    }
  ]
}

module "template-ns-ssh_server" {
  for_each = local.ns.hosts

  source     = "./modules/ssh_server"
  key_id     = each.value.hostname
  user_names = [local.common.users.admin.name]
  valid_principals = compact(concat([each.value.hostname, "127.0.0.1"], flatten([
    for interface in values(module.template-ns-guest_interfaces[each.key].interfaces) :
    try(cidrhost(interface.prefix, each.value.netnum), null)
  ])))
  ssh_ca = local.common.ca.ssh
}

# combine and render a single ignition file #
data "ct_config" "ns" {
  for_each = local.ns.hosts

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
  for_each = local.ns.hosts

  content  = data.ct_config.ns[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}