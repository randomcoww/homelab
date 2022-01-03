locals {
  hypervisors = {
    kvm-0 = {
      hostname = join(".", "kvm-0", local.common.domains.mdns)
      interfaces = {
        en0 = {
          mac = "8c-8c-aa-e3-58-62"
          mtu = 9000
          taps = {
            lan = {
              netnum = 1
              mdns = true
              dhcp = true
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
              wipe = true
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

  source = "modules/hypervisor"
  name = each.key
  hostname = each.value.hostname
  user            = local.common.admin_user
  vlans = local.common.vlans
  interfaces = each.value.interfaces
  ca = {
    matchbox = {
      algorithm = tls_private_key.matchbox-ca.algorithm
      private_key_pem = tls_private_key.matchbox-ca.private_key_pem
      cert_pem = tls_self_signed_cert.matchbox-ca.cert_pem
    }
    libvirt = {
      algorithm = tls_private_key.libvirt-ca.algorithm
      private_key_pem = tls_private_key.libvirt-ca.private_key_pem
      cert_pem = tls_self_signed_cert.libvirt-ca.cert_pem
    }
  }
}

module "template-ssh_server" {
  for_each = local.hypervisors

  source = "modules/ssh_server"
  name = each.key
  hostname = each.value.hostname
  user            = local.common.admin_user
  vlans = local.common.vlans
  interfaces = each.value.interfaces
  ca = {
    ssh = {
      algorithm = tls_private_key.ssh-ca.algorithm
      private_key_pem = tls_private_key.ssh-ca.private_key_pem
    }
  }
}

module "template-disks" {
  for_each = local.hypervisors

  source = "modules/disks"
  name = each.key
  disks = each.value.disks
}

# combine and render a single ignition file #
data "ct_config" "hypervisor" {
  for_each = local.hypervisors

  content  = <<EOT
---
variant: fcos
version: 1.4.0
EOT
  strict   = true
  snippets = concat([
    module.template-hypervisor[each.key].ignition,
    module.template-ssh[each.key].ignition,
    module.template-disks[each.key].ignition,
  ])
}

resource "local_file" "hypervisor" {
  for_each = local.hypervisors

  content  = data.ct_config.hypervisor[each.key].rendered
  filename = "output/ignition/${each.key}.ign"
}