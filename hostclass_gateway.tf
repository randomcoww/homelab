locals {
  gateway_hostclass_config = {
    vrrp_netnum = 1
    hosts = {
      gateway-0 = {
        hostname = "gateways-0.${local.config.domains.internal_mdns}"
        netnum   = 4
        interfaces = {
          internal = {
            enable_unmanaged = true
          }
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
module "template-gateway-guest_interfaces" {
  for_each = local.gateway_hostclass_config.hosts

  source      = "./modules/guest_interfaces"
  networks    = local.config.networks
  host_netnum = each.value.netnum
  interfaces  = each.value.interfaces
}

module "template-gateway" {
  for_each = local.gateway_hostclass_config.hosts

  source           = "./modules/gateway"
  hostname         = each.value.hostname
  user             = local.config.users.admin
  guest_interfaces = module.template-gateway-guest_interfaces[each.key].interfaces
  container_images = local.config.container_images
  netnums = {
    host = each.value.netnum
    vrrp = local.ns_hostclass_config.vrrp_netnum
  }
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
}

# combine and render a single ignition file #
data "ct_config" "gateway" {
  for_each = local.gateway_hostclass_config.hosts

  content = <<EOT
---
variant: fcos
version: 1.4.0
EOT
  strict  = true
  snippets = concat(
    module.template-gateway-guest_interfaces[each.key].ignition_snippets,
    module.template-gateway[each.key].ignition_snippets,
  )
}

resource "local_file" "gateway" {
  for_each = local.gateway_hostclass_config.hosts

  content  = data.ct_config.gateway[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}