locals {
  ns = {
    vrrp_netnum = 3
    dhcp_server = {
      newbit = 1
      netnum = 1
    }
    hosts = {
      ns-0 = {
        hostname = "ns-0.${local.common.domains.internal_mdns}"
        netnum   = 1
        interfaces = {
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
        netnum   = 2
        interfaces = {
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
module "template-ns" {
  for_each = local.ns.hosts

  source      = "./modules/ns"
  hostname    = each.value.hostname
  user        = local.common.admin_user
  networks    = local.common.networks
  interfaces  = each.value.interfaces
  domains     = local.common.domains
  dhcp_server = local.ns.dhcp_server
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
  domain_interfaces = [
    {
      network_name              = "internal"
      hypervisor_interface_name = "internal"
      boot_order                = 1
    },
    {
      network_name              = "lan"
      hypervisor_interface_name = "en0-lan"
    },
  ]
  container_images = local.common.container_images
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
    module.template-ns[each.key].ignition,
  )
}

resource "local_file" "ns" {
  for_each = local.ns.hosts

  content  = data.ct_config.ns[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}