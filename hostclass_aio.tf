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
module "template-aio-base" {
  for_each = local.aio_hostclass_config.hosts

  source                 = "./modules/base"
  hostname               = each.value.hostname
  users                  = [local.config.users.admin]
  container_storage_path = "${each.value.disks.pv.partitions[0].mount_path}/containers"
}

module "template-aio-server" {
  for_each = local.aio_hostclass_config.hosts

  source              = "./modules/server"
  networks            = local.config.networks
  hardware_interfaces = each.value.hardware_interfaces
  tap_interfaces      = each.value.tap_interfaces
  host_netnum         = each.value.netnum
}

module "template-aio-gateway" {
  for_each = local.aio_hostclass_config.hosts

  source             = "./modules/gateway"
  hostname           = each.value.hostname
  user               = local.config.users.admin
  interfaces         = module.template-aio-server[each.key].interfaces
  container_images   = local.config.container_images
  dhcp_server_subnet = local.aio_hostclass_config.dhcp_server_subnet
  kea_peer_port      = local.config.ports.kea_peer
  host_netnum        = each.value.netnum
  vrrp_netnum        = local.aio_hostclass_config.vrrp_netnum
  kea_peers = [
    for host in values(local.aio_hostclass_config.hosts) :
    {
      name   = host.hostname
      role   = lookup(host, "kea_ha_role", "backup")
      netnum = host.netnum
    }
  ]
  internal_dns_ip   = local.config.internal_dns_ip
  internal_domain   = local.config.domains.internal
  pxeboot_file_name = local.config.pxeboot_file_name
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
    for interface in values(module.template-aio-server[each.key].interfaces) :
    try(cidrhost(interface.prefix, each.value.netnum), null)
    if lookup(interface, "enable_netnum", false)
  ])))
  ssh_ca = local.config.ca.ssh
}

module "template-aio-hypervisor" {
  for_each = local.aio_hostclass_config.hosts

  source    = "./modules/hypervisor"
  dns_names = [each.value.hostname]
  ip_addresses = compact(concat(["127.0.0.1"], flatten([
    for interface in values(module.template-aio-server[each.key].interfaces) :
    try(cidrhost(interface.prefix, each.value.netnum), null)
    if lookup(interface, "enable_netnum", false)
  ])))
  libvirt_ca = local.config.ca.libvirt
}

# kubernetes #
module "template-aio-kubelet" {
  for_each = local.aio_hostclass_config.hosts

  source           = "./modules/kubelet"
  container_images = local.config.container_images
  network_prefix   = local.config.networks.lan.prefix
  host_netnum      = each.value.netnum
}

module "template-aio-etcd" {
  for_each = local.aio_hostclass_config.hosts

  source           = "./modules/etcd"
  hostname         = each.value.hostname
  container_images = local.config.container_images
  common_certs     = module.kubernetes-common.certs
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
  etcd_cluster_token    = local.config.kubernetes_cluster_name
  aws_access_key_id     = module.kubernetes-common.aws_s3_backup_credentials.access_key_id
  aws_secret_access_key = module.kubernetes-common.aws_s3_backup_credentials.access_key_secret
  aws_region            = local.config.aws_region
  etcd_s3_backup_path   = module.kubernetes-common.etcd_s3_backup_key
  etcd_ca               = module.kubernetes-common.ca.etcd
}

module "template-aio-kubernetes" {
  for_each = local.aio_hostclass_config.hosts

  source                            = "./modules/kubernetes"
  hostname                          = each.value.hostname
  container_images                  = local.config.container_images
  common_certs                      = module.kubernetes-common.certs
  network_prefix                    = local.config.networks.lan.prefix
  host_netnum                       = each.value.netnum
  vip_netnum                        = local.aio_hostclass_config.vrrp_netnum
  apiserver_port                    = local.config.ports.apiserver
  etcd_client_port                  = local.config.ports.etcd_client
  etcd_servers                      = [module.template-aio-etcd[each.key].local_client_endpoint]
  kubernetes_cluster_name           = local.config.kubernetes_cluster_name
  kubernetes_service_network_prefix = local.config.networks.kubernetes_service.prefix
  kubernetes_pod_network_prefix     = local.config.networks.kubernetes_pod.prefix
  encryption_config_secret          = module.kubernetes-common.encryption_config_secret
  kubernetes_ca                     = module.kubernetes-common.ca.kubernetes
}

module "template-aio-worker" {
  for_each = local.aio_hostclass_config.hosts

  source                        = "./modules/worker"
  container_images              = local.config.container_images
  common_certs                  = module.kubernetes-common.certs
  apiserver_ip                  = "127.0.0.1"
  apiserver_port                = local.config.ports.apiserver
  kubernetes_cluster_name       = local.config.kubernetes_cluster_name
  kubernetes_cluster_domain     = local.config.domains.kubernetes
  kubernetes_pod_network_prefix = local.config.networks.kubernetes_pod.prefix
  kubernetes_cluster_dns_netnum = local.config.kubernetes_cluster_dns_netnum
  kubelet_node_labels           = {}
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
    module.template-aio-base[each.key].ignition_snippets,
    module.template-aio-server[each.key].ignition_snippets,
    module.template-aio-gateway[each.key].ignition_snippets,
    module.template-aio-disks[each.key].ignition_snippets,
    module.template-aio-ssh_server[each.key].ignition_snippets,
    module.template-aio-hypervisor[each.key].ignition_snippets,
    module.template-aio-kubelet[each.key].ignition_snippets,
    module.template-aio-etcd[each.key].ignition_snippets,
    module.template-aio-kubernetes[each.key].ignition_snippets,
    module.template-aio-worker[each.key].ignition_snippets,
  )
}

resource "local_file" "aio" {
  for_each = local.aio_hostclass_config.hosts

  content  = data.ct_config.aio[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}