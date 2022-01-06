locals {
  gateways = {
    gateways-0 = {
      hostname = "gateways-0.${local.common.domains.internal_mdns}"
      interfaces = {
        lan = {
          mdns        = true
          vrrp_netnum = local.common.networks.lan.router_netnum
          mtu         = 9000
        }
        sync = {
          netnum      = 10
          vrrp_netnum = local.common.networks.lan.router_netnum
          mtu         = 9000
        }
        wan = {
          dhcp = true
        }
      }
    }
  }
}

# templates #
module "template-gateway" {
  for_each = local.gateways

  source     = "./host_classes/gateway"
  hostname   = each.value.hostname
  user       = local.common.admin_user
  networks   = local.common.networks
  interfaces = each.value.interfaces
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
  for_each = local.gateways

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
  for_each = local.gateways

  content  = data.ct_config.gateway[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}