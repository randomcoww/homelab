locals {
  client_hostclass_config = {
    hosts = {
      client-0 = {
        hostname = "clients-0.${local.config.domains.internal_mdns}"
        disks = {
          pv = {
            device = "/dev/disk/by-id/ata-INTEL_SSDSA2BZ100G3D_CVLV2345008U100AGN"
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
module "template-client-base" {
  for_each = local.client_hostclass_config.hosts

  source                 = "./modules/base"
  hostname               = each.value.hostname
  users                  = [local.config.users.client]
  container_storage_path = "${each.value.disks.pv.partitions[0].mount_path}/containers"
}

module "template-client-desktop" {
  for_each = local.client_hostclass_config.hosts

  source                    = "./modules/desktop"
  ssh_ca_public_key_openssh = local.config.ca.ssh.public_key_openssh
}

module "template-client-disks" {
  for_each = local.client_hostclass_config.hosts

  source = "./modules/disks"
  disks  = each.value.disks
}

# combine and render a single ignition file #
data "ct_config" "client" {
  for_each = local.client_hostclass_config.hosts

  content = <<EOT
---
variant: fcos
version: 1.4.0
EOT
  strict  = true
  snippets = concat(
    module.template-client-base[each.key].ignition_snippets,
    module.template-client-desktop[each.key].ignition_snippets,
    module.template-client-disks[each.key].ignition_snippets,
  )
}

resource "local_file" "client" {
  for_each = local.client_hostclass_config.hosts

  content  = data.ct_config.client[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}