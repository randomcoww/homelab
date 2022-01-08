locals {
  hypervisor_hostclass_config = {
    internal_interface = {
      interface_name = "internal"
      netnum         = 1
      dhcp_subnet = {
        newbit = 1
        netnum = 1
      }
    }
    hosts = {
      hypervisor-0 = {
        hostname = "hypervisor-0.${local.config.domains.internal_mdns}"
        hardware_interfaces = {
          phy0 = {
            netnum = 7
            mac    = "8c-8c-aa-e3-58-62"
            mtu    = 9000
            interfaces = {
              lan = {
                enable_netnum = true
                enable_mdns   = true
              }
              sync = {
              }
              wan = {
              }
            }
          }
        }
        disks = {
          pv = {
            device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_1TB_S5H9NS0N986704R"
            partitions = [
              {
                mount_path = "/var/lib/kubelet/pv"
                wipe       = false
              },
            ]
          }
        }
      }
    }
  }
}

# templates #
module "template-hypervisor" {
  for_each = local.hypervisor_hostclass_config.hosts

  source   = "./modules/hypervisor"
  hostname = each.value.hostname
  user = merge(local.config.users.admin, {
    groups = concat(lookup(local.config.users.admin, "groups", []), [
      "libvirt"
    ])
  })
  networks            = local.config.networks
  hardware_interfaces = each.value.hardware_interfaces
  internal_interface  = local.hypervisor_hostclass_config.internal_interface
  matchbox_ca         = local.config.ca.matchbox
  libvirt_ca          = local.config.ca.libvirt
  container_images    = local.config.container_images
}

module "template-hypervisor-disks" {
  for_each = local.hypervisor_hostclass_config.hosts

  source = "./modules/disks"
  disks  = each.value.disks
}

module "template-hypervisor-ssh_server" {
  for_each = local.hypervisor_hostclass_config.hosts

  source     = "./modules/ssh_server"
  key_id     = each.value.hostname
  user_names = [local.config.users.admin.name]
  valid_principals = compact(concat([each.value.hostname, "127.0.0.1"], flatten([
    for hardware_interface in values(module.template-hypervisor[each.key].hardware_interfaces) :
    [
      for interface in values(hardware_interface.interfaces) :
      try(cidrhost(interface.prefix, hardware_interface.netnum), null)
    ]
  ])))
  ssh_ca = local.config.ca.ssh
}

# combine and render a single ignition file #
data "ct_config" "hypervisor" {
  for_each = local.hypervisor_hostclass_config.hosts

  content = <<EOT
---
variant: fcos
version: 1.4.0
EOT
  strict  = true
  snippets = concat(
    module.template-hypervisor[each.key].ignition_snippets,
    module.template-hypervisor-disks[each.key].ignition_snippets,
    module.template-hypervisor-ssh_server[each.key].ignition_snippets,
  )
}

resource "local_file" "hypervisor" {
  for_each = local.hypervisor_hostclass_config.hosts

  content  = data.ct_config.hypervisor[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}