locals {
  aio_hostclass_config = {
    vrrp_netnum = 2
    dhcp_server_subnet = {
      newbit = 1
      netnum = 1
    }
    hosts = {
      aio-0 = {
        hostname = "aio-0.${local.config.domains.internal_mdns}"
        netnum   = 1
        hardware_interfaces = {
          phy0 = {
            mac   = "8c-8c-aa-e3-58-62"
            mtu   = 9000
            vlans = ["lan", "sync", "wan"]
          }
          wlan0 = {
            mac = "b4-0e-de-fb-28-95"
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
module "template-aio-gateway_base" {
  for_each = local.aio_hostclass_config.hosts

  source              = "./modules/gateway_base"
  hostname            = each.value.hostname
  user                = local.config.users.admin
  networks            = local.config.networks
  hardware_interfaces = each.value.hardware_interfaces
  tap_interfaces      = each.value.tap_interfaces
  container_images    = local.config.container_images
  dhcp_server_subnet  = local.aio_hostclass_config.dhcp_server_subnet
  kea_peer_port       = local.config.ports.kea_peer
  host_netnum         = each.value.netnum
  vrrp_netnum         = local.aio_hostclass_config.vrrp_netnum
  kea_peers = [
    for host in values(local.aio_hostclass_config.hosts) :
    {
      name   = host.hostname
      role   = lookup(host, "kea_ha_role", "backup")
      netnum = host.netnum
    }
  ]
  internal_dns_ip        = local.config.internal_dns_ip
  internal_domain        = local.config.domains.internal
  container_storage_path = "${each.value.disks.pv.partitions[0].mount_path}/containers"
  pxeboot_file_name      = local.config.pxeboot_file_name
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
    for interface in values(module.template-aio-gateway_base[each.key].interfaces) :
    try(cidrhost(interface.prefix, each.value.netnum), null)
  ])))
  ssh_ca = local.config.ca.ssh
}

module "template-aio-hypervisor" {
  for_each = local.aio_hostclass_config.hosts

  source      = "./modules/hypervisor"
  interfaces  = module.template-aio-gateway_base[each.key].interfaces
  host_netnum = each.value.netnum
  libvirt_ca  = local.config.ca.libvirt
}

module "template-aio-etcd" {
  for_each = local.aio_hostclass_config.hosts

  source           = "./modules/etcd"
  etcd_peer_port   = local.config.ports.etcd_peer
  etcd_client_port = local.config.ports.etcd_client
  etcd_hosts = [
    for host in values(local.aio_hostclass_config.hosts) :
    {
      name   = host.hostname
      netnum = host.netnum
    }
  ]
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
    module.template-aio-hypervisor[each.key].ignition_snippets,
  )
}

resource "local_file" "aio" {
  for_each = local.aio_hostclass_config.hosts

  content  = data.ct_config.aio[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}