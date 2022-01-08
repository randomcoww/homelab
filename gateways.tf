locals {
  gateways = {
    vrrp_netnum = 1
    hosts = {
      gateways-0 = {
        hostname = "gateways-0.${local.common.domains.internal_mdns}"
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
module "template-gateway" {
  for_each = local.gateways.hosts

  source                 = "./modules/gateway"
  hostname               = each.value.hostname
  user                   = local.common.users.admin
  networks               = local.common.networks
  interfaces             = each.value.interfaces
  interface_device_order = local.common.interface_device_order
  container_images       = local.common.container_images
  system_image_tag       = local.common.system_image_tags.server
  netnums = {
    host = each.value.netnum
    vrrp = local.ns.vrrp_netnum
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
  for_each = local.gateways.hosts

  content = <<EOT
---
variant: fcos
version: 1.4.0
EOT
  strict  = true
  snippets = concat(
    module.template-gateway[each.key].ignition_snippets,
  )
}

resource "local_file" "gateway" {
  for_each = local.gateways.hosts

  content  = data.ct_config.gateway[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}