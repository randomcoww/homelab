locals {
  hypervisors = {
    kvm-0 = {
      hostname = "kvm-0.${local.common.domains.internal_mdns}"
      hardware_interfaces = {
        en0 = {
          mac = "8c-8c-aa-e3-58-62"
          mtu = 9000
          networks = {
            lan = {
              netnum = 1
              mdns   = true
            }
            sync = {
              netnum = 1
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

# templates #
module "template-hypervisor" {
  for_each = local.hypervisors

  source              = "./modules/hypervisor"
  hostname            = each.value.hostname
  user                = local.common.admin_user
  networks            = local.common.networks
  hardware_interfaces = each.value.hardware_interfaces
  matchbox_ca         = local.common.ca.matchbox
  libvirt_ca          = local.common.ca.libvirt
  ssh_ca              = local.common.ca.ssh
}

module "template-disks" {
  for_each = local.hypervisors

  source = "./modules/disks"
  disks  = each.value.disks
}

# combine and render a single ignition file #
data "ct_config" "hypervisor" {
  for_each = local.hypervisors

  content = <<EOT
---
variant: fcos
version: 1.4.0
EOT
  strict  = true
  snippets = concat(
    module.template-hypervisor[each.key].ignition,
    module.template-disks[each.key].ignition,
  )
}

resource "local_file" "hypervisor" {
  for_each = local.hypervisors

  content  = data.ct_config.hypervisor[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}