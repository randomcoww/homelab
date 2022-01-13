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
  etcd_cluster_token = "2201"
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

  source    = "./modules/hypervisor"
  dns_names = [each.value.hostname]
  ip_addresses = compact(concat(["127.0.0.1"], flatten([
    for interface in values(module.template-aio-gateway_base[each.key].interfaces) :
    try(cidrhost(interface.prefix, each.value.netnum), null)
  ])))
  libvirt_ca = local.config.ca.libvirt
}

# kubernetes #
module "kubernetes-common-default" {
  source             = "./modules/kubernetes_common"
  etcd_s3_backup_key = "randomcoww-etcd-backup/2201"
}

module "template-aio-etcd" {
  for_each = local.aio_hostclass_config.hosts

  source           = "./modules/etcd"
  hostname         = each.value.hostname
  container_images = local.config.container_images
  common_certs     = module.kubernetes-common-default.certs
  network_prefix   = local.config.networks.lan.prefix
  host_netnum      = each.value.netnum
  etcd_hosts = [
    for host in values(local.aio_hostclass_config.hosts) :
    {
      name   = host.hostname
      netnum = host.netnum
    }
  ]
  etcd_client_port      = local.config.ports.etcd_client
  etcd_peer_port        = local.config.ports.etcd_peer
  etcd_cluster_token    = local.etcd_cluster_token
  aws_access_key_id     = module.kubernetes-common-default.aws_s3_backup_credentials.access_key_id
  aws_secret_access_key = module.kubernetes-common-default.aws_s3_backup_credentials.access_key_secret
  aws_region            = local.config.aws_region
  etcd_s3_backup_path   = "randomcoww-etcd-backup/${local.etcd_cluster_token}"
  etcd_ca               = module.kubernetes-common-default.ca.etcd
}

module "template-aio-kubernetes" {
  for_each = local.aio_hostclass_config.hosts

  source                            = "./modules/kubernetes"
  hostname                          = each.value.hostname
  container_images                  = local.config.container_images
  common_certs                      = module.kubernetes-common-default.certs
  network_prefix                    = local.config.networks.lan.prefix
  host_netnum                       = each.value.netnum
  vip_netnum                        = local.aio_hostclass_config.vrrp_netnum
  apiserver_port                    = local.config.ports.apiserver
  etcd_client_port                  = local.config.ports.etcd_client
  etcd_servers                      = [module.template-aio-etcd[each.key].local_client_endpoint]
  kubernetes_cluster_name           = "cluster-${local.etcd_cluster_token}"
  kubernetes_cluster_domain         = local.config.domains.kubernetes
  kubernetes_service_network_prefix = local.config.networks.kubernetes.prefix
  kubernetes_network_prefix         = local.config.networks.kubernetes_service.prefix
  kubelet_node_labels               = {}
  encryption_config_secret          = module.kubernetes-common-default.encryption_config_secret
  kubernetes_ca                     = module.kubernetes-common-default.ca.kubernetes
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
    module.template-aio-gateway_base[each.key].ignition_snippets,
    module.template-aio-disks[each.key].ignition_snippets,
    module.template-aio-ssh_server[each.key].ignition_snippets,
    module.template-aio-hypervisor[each.key].ignition_snippets,
    module.template-aio-etcd[each.key].ignition_snippets,
    module.template-aio-kubernetes[each.key].ignition_snippets,
  )
}

resource "local_file" "aio" {
  for_each = local.aio_hostclass_config.hosts

  content  = data.ct_config.aio[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}