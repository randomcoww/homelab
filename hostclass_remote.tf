locals {
  remote_hostclass_config = {
    hosts = {
      remote-0 = merge(local.host_spec.client-laptop, {
        hostname = "remote-0.${local.domains.internal_mdns}"
      })
    }
  }
}

# templates #
module "template-remote-base" {
  for_each = local.remote_hostclass_config.hosts

  source   = "./modules/base"
  hostname = each.value.hostname
  users    = [local.users.client]
}

module "template-remote-desktop" {
  for_each = local.remote_hostclass_config.hosts

  source                    = "./modules/desktop"
  ssh_ca_public_key_openssh = module.ssh-server-common.ca.ssh.public_key_openssh
}

module "template-remote-disks" {
  for_each = local.remote_hostclass_config.hosts

  source = "./modules/disks"
  disks  = each.value.disks
}

# combine and render a single ignition file #
data "ct_config" "remote" {
  for_each = local.remote_hostclass_config.hosts

  content = <<EOT
---
variant: fcos
version: 1.4.0
EOT
  strict  = true
  snippets = concat(
    module.template-remote-base[each.key].ignition_snippets,
    module.template-remote-desktop[each.key].ignition_snippets,
    module.template-remote-disks[each.key].ignition_snippets,
  )
}

resource "local_file" "remote" {
  for_each = local.remote_hostclass_config.hosts

  content  = data.ct_config.remote[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}