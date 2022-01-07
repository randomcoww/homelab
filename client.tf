locals {
  clients = {
    hosts = {
      clients-0 = {
        hostname = "clients-0.${local.common.domains.internal_mdns}"
        disks = {
          pv = {
            device = "/dev/disk/by-id/nvme-SKHynix_HFS512GDE9X084N_CYA8N037413008I5H"
            partitions = [
              {
                mount_path = "/var/home"
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
module "template-client" {
  for_each = local.clients.hosts

  source                    = "./modules/client"
  hostname                  = each.value.hostname
  user                      = local.common.users.client
  ssh_ca_public_key_openssh = local.common.ca.ssh.public_key_openssh
}

module "template-client-disks" {
  for_each = local.clients.hosts

  source = "./modules/disks"
  disks  = each.value.disks
}

# combine and render a single ignition file #
data "ct_config" "client" {
  for_each = local.clients.hosts

  content = <<EOT
---
variant: fcos
version: 1.4.0
EOT
  strict  = true
  snippets = concat(
    module.template-client[each.key].ignition_snippets,
    module.template-client-disks[each.key].ignition_snippets,
  )
}

resource "local_file" "client" {
  for_each = local.clients.hosts

  content  = data.ct_config.client[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}