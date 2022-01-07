locals {
  gateways = {
    vrrp_netnum = 3
    hosts = {
      gateways-0 = {
        hostname = "gateways-0.${local.common.domains.internal_mdns}"
        netnum   = 2
        interfaces = {
          lan = {
            enable_mdns        = true
            enable_vrrp_netnum = true
            mtu                = 9000
          }
          sync = {
            enable_netnum      = true
            enable_vrrp_netnum = true
            mtu                = 9000
          }
          wan = {
            enable_dhcp = true
          }
        }
      }
    }
  }
}

# templates #
module "template-gateway" {
  for_each = local.gateways.hosts

  source     = "./modules/gateway"
  hostname   = each.value.hostname
  user       = local.common.admin_user
  networks   = local.common.networks
  interfaces = each.value.interfaces
  netnums = {
    host = each.value.netnum
    vrrp = local.ns.vrrp_netnum
  }
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
    {
      network_name              = "sync"
      hypervisor_interface_name = "en0-sync"
    },
    {
      network_name              = "wan"
      hypervisor_interface_name = "en0-wan"
    },
  ]

  # master route prioirty is slotted in between main and slave
  # when keepalived becomes master on the host
  # priority for both should be greater than 32767 (default)
  master_default_route = {
    table_id       = 250
    table_priority = 32770
  }
  slave_default_route = {
    table_id       = 240
    table_priority = 32780
  }
  container_images = local.common.container_images
}

# combine and render a single ignition file #
data "ct_config" "gateway" {
  for_each = local.gateways.hosts

  content = <<EOT
---
variant: fcos
version: 1.4.0
EOT
  strict  = true
  snippets = concat(
    module.template-gateway[each.key].ignition,
  )
}

resource "local_file" "gateway" {
  for_each = local.gateways.hosts

  content  = data.ct_config.gateway[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}