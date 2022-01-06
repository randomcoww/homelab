locals {
  ns = {
    ns-0 = {
      hostname = "ns-0.${local.common.domains.internal_mdns}"
      interfaces = {
        lan = {
          mdns        = true
          mtu         = 9000
          vrrp_netnum = 2
          dhcp_subnet = {
            newbit = 1
            netnum = 1
          }
        }
      }
    }
  }
}

# templates #
module "template-ns" {
  for_each = local.ns

  source     = "./host_classes/ns"
  hostname   = each.value.hostname
  user       = local.common.admin_user
  networks   = local.common.networks
  interfaces = each.value.interfaces
  domains    = local.common.domains
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
  for_each = local.ns

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
  for_each = local.ns

  content  = data.ct_config.ns[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}