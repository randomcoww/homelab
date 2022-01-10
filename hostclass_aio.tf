locals {
  aio_hostclass_config = {
    vrrp_netnum = 2
    dhcp_server = {
      newbit = 1
      netnum = 1
    }
    hosts = {
      aio-0 = {
        hostname = "aio-0.${local.config.domains.internal_mdns}"
        netnum   = 1
        hardware_interfaces = {
          phy0 = {
            mac = "8c-8c-aa-e3-58-62"
            mtu = 9000
          }
        }
        tap_interfaces = {
          lan = {
            hardware_interface_name = "phy0"
            enable_mdns             = true
            enable_netnum           = true
            enable_vrrp_netnum      = true
            enable_dhcp_server      = true
            mtu                     = 9000
          }
          sync = {
            hardware_interface_name = "phy0"
            enable_netnum           = true
            enable_vrrp_netnum      = true
            mtu                     = 9000
          }
          wan = {
            hardware_interface_name = "phy0"
            enable_dhcp             = true
            macaddress              = "52-54-00-63-6e-b3"
          }
        }
        disks = {
          pv = {
            device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_1TB_S5H9NS0N986704R"
            partitions = [
              {
                mount_path = "/var/pv"
                wipe       = false
              },
            ]
          }
        }
        kea_ha_role = "primary"
      }
    }
  }
}

# templates #
module "template-aio" {
  for_each = local.aio_hostclass_config.hosts

  source                 = "./modules/aio"
  name                   = each.key
  hostname               = each.value.hostname
  user                   = local.config.users.admin
  networks               = local.config.networks
  hardware_interfaces    = each.value.hardware_interfaces
  tap_interfaces         = each.value.tap_interfaces
  dhcp_server            = local.aio_hostclass_config.dhcp_server
  libvirt_ca             = local.config.ca.libvirt
  container_images       = local.config.container_images
  container_storage_path = "${each.value.disks.pv.partitions[0].mount_path}/containers"
  netnums = {
    host = each.value.netnum
    vrrp = local.aio_hostclass_config.vrrp_netnum
  }
  kea_peers = {
    for host_key, host in local.aio_hostclass_config.hosts :
    host_key => {
      name   = host.hostname
      role   = host.kea_ha_role
      netnum = host.netnum
      port   = 58080
    }
    if can(host.kea_ha_role)
  }
  pxeboot_file_name = local.config.pxeboot_file_name
  internal_dns_ip   = local.config.internal_dns_ip
  internal_domain   = local.config.domains.internal
}

module "template-aio-disks" {
  for_each = local.aio_hostclass_config.hosts

  source = "./modules/disks"
  disks  = each.value.disks
}

module "template-aio-ssh_server" {
  for_each = local.aio_hostclass_config.hosts

  source     = "./modules/ssh_server"
  key_id     = each.value.hostname
  user_names = [local.config.users.admin.name]
  valid_principals = compact(concat([each.value.hostname, "127.0.0.1"], flatten([
    for interface in values(module.template-aio[each.key].interfaces) :
    try(cidrhost(interface.prefix, each.value.netnum), null)
  ])))
  ssh_ca = local.config.ca.ssh
}

# combine and render a single ignition file #
data "ct_config" "aio" {
  for_each = local.aio_hostclass_config.hosts

  content = <<EOT
---
variant: fcos
version: 1.4.0
EOT
  strict  = true
  snippets = concat(
    module.template-aio[each.key].ignition_snippets,
    module.template-aio-disks[each.key].ignition_snippets,
    module.template-aio-ssh_server[each.key].ignition_snippets,
  )
}

resource "local_file" "aio" {
  for_each = local.aio_hostclass_config.hosts

  content  = data.ct_config.aio[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}