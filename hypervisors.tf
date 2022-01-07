locals {
  hypervisors = {
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
        hostname = "hypervisor-0.${local.common.domains.internal_mdns}"
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
                enable_netnum = true
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
                wipe       = true
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
  for_each = local.hypervisors.hosts

  source              = "./modules/hypervisor"
  hostname            = each.value.hostname
  user                = local.common.users.admin
  networks            = local.common.networks
  hardware_interfaces = each.value.hardware_interfaces
  internal_interface  = local.hypervisors.internal_interface
  matchbox_ca         = local.common.ca.matchbox
  libvirt_ca          = local.common.ca.libvirt
  ssh_ca              = local.common.ca.ssh
}

module "template-disks" {
  for_each = local.hypervisors.hosts

  source = "./modules/disks"
  disks  = each.value.disks
}

# combine and render a single ignition file #
data "ct_config" "hypervisor" {
  for_each = local.hypervisors.hosts

  content = <<EOT
---
variant: fcos
version: 1.4.0
EOT
  strict  = true
  snippets = concat(
    module.template-hypervisor[each.key].ignition_snippets,
    module.template-disks[each.key].ignition_snippets,
  )
}

resource "local_file" "hypervisor" {
  for_each = local.hypervisors.hosts

  content  = data.ct_config.hypervisor[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}