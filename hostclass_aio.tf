locals {
  aio_hostclass_config = {
    vrrp_netnum = 2
    dhcp_server_subnet = {
      newbit = 1
      netnum = 1
    }
    hosts = {
      aio-0 = merge(local.host_spec.server-laptop, {
        hostname    = "aio-0.${local.config.domains.internal_mdns}"
        netnum      = 1
        kea_ha_role = "primary"
      })
    }
  }
}

# templates #
module "template-aio-base" {
  for_each = local.aio_hostclass_config.hosts

  source   = "./modules/base"
  hostname = each.value.hostname
  users    = [local.config.users.admin]
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
    for host in concat(
      values(local.aio_hostclass_config.hosts),
      values(local.router_hostclass_config.hosts),
    ) :
    {
      name   = host.hostname
      role   = lookup(host, "kea_ha_role", "backup")
      netnum = host.netnum
    }
  ]
  internal_dns_ip = cidrhost(
    cidrsubnet(local.config.networks.lan.prefix, local.config.metallb_subnet.newbit, local.config.metallb_subnet.netnum),
    local.config.metallb_external_dns_netnum
  )
  internal_domain = local.config.domains.internal
  pxeboot_file_name = "http://${cidrhost(
    cidrsubnet(local.config.networks.lan.prefix, local.config.metallb_subnet.newbit, local.config.metallb_subnet.netnum),
    local.config.metallb_external_dns_netnum
  )}/boot.ipxe"
  static_pod_manifest_path = local.config.static_pod_manifest_path
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

  source                   = "./modules/kubelet"
  container_images         = local.config.container_images
  network_prefix           = local.config.networks.lan.prefix
  host_netnum              = each.value.netnum
  static_pod_manifest_path = local.config.static_pod_manifest_path
}

module "template-aio-etcd" {
  for_each = local.aio_hostclass_config.hosts

  source           = "./modules/etcd"
  hostname         = each.value.hostname
  container_images = local.config.container_images
  common_certs     = module.etcd-common.certs
  network_prefix   = local.config.networks.lan.prefix
  host_netnum      = each.value.netnum
  etcd_hosts = [
    for host in values(local.aio_hostclass_config.hosts) :
    {
      name   = host.hostname
      netnum = host.netnum
    }
  ]
  etcd_client_port         = local.config.ports.etcd_client
  etcd_peer_port           = local.config.ports.etcd_peer
  etcd_cluster_token       = local.config.kubernetes_cluster_name
  aws_access_key_id        = module.etcd-common.aws_user_access.id
  aws_access_key_secret    = module.etcd-common.aws_user_access.secret
  aws_region               = "us-west-2"
  s3_backup_path           = module.etcd-common.s3_backup_path
  etcd_ca                  = module.etcd-common.ca.etcd
  static_pod_manifest_path = local.config.static_pod_manifest_path
}

module "template-aio-kubernetes" {
  for_each = local.aio_hostclass_config.hosts

  source                                      = "./modules/kubernetes"
  hostname                                    = each.value.hostname
  container_images                            = local.config.container_images
  kubernetes_common_certs                     = module.kubernetes-common.certs.kubernetes
  etcd_common_certs                           = module.etcd-common.certs.etcd
  network_prefix                              = local.config.networks.lan.prefix
  host_netnum                                 = each.value.netnum
  vip_netnum                                  = local.aio_hostclass_config.vrrp_netnum
  apiserver_port                              = local.config.ports.apiserver
  controller_manager_port                     = local.config.ports.controller_manager_port
  scheduler_port                              = local.config.ports.scheduler_port
  etcd_client_port                            = local.config.ports.etcd_client
  etcd_servers                                = [module.template-aio-etcd[each.key].local_client_endpoint]
  kubernetes_cluster_name                     = local.config.kubernetes_cluster_name
  kubernetes_service_network_prefix           = local.config.networks.kubernetes_service.prefix
  kubernetes_pod_network_prefix               = local.config.networks.kubernetes_pod.prefix
  kubernetes_service_network_apiserver_netnum = local.config.kubernetes_service_network_apiserver_netnum
  encryption_config_secret                    = module.kubernetes-common.encryption_config_secret
  kubernetes_ca                               = module.kubernetes-common.ca.kubernetes
  static_pod_manifest_path                    = local.config.static_pod_manifest_path
}

module "template-aio-worker" {
  for_each = local.aio_hostclass_config.hosts

  source                                = "./modules/worker"
  container_images                      = local.config.container_images
  common_certs                          = module.kubernetes-common.certs
  apiserver_ip                          = "127.0.0.1"
  apiserver_port                        = local.config.ports.apiserver
  kubelet_port                          = local.config.ports.kubelet
  kubernetes_cluster_name               = local.config.kubernetes_cluster_name
  kubernetes_cluster_domain             = local.config.domains.kubernetes
  kubernetes_service_network_prefix     = local.config.networks.kubernetes_service.prefix
  kubernetes_service_network_dns_netnum = local.config.kubernetes_service_network_dns_netnum
  kubelet_node_labels                   = {}
  static_pod_manifest_path              = local.config.static_pod_manifest_path
  container_storage_path                = each.value.container_storage_path
}

module "template-aio-minio" {
  for_each = local.aio_hostclass_config.hosts

  source                   = "./modules/minio"
  minio_container_image    = local.config.container_images.minio
  minio_port               = local.config.ports.minio
  minio_console_port       = local.config.ports.minio_console
  volume_paths             = each.value.minio_volume_paths
  static_pod_manifest_path = local.config.static_pod_manifest_path
}

module "template-aio-hostapd" {
  for_each = local.aio_hostclass_config.hosts

  source                   = "./modules/hostapd"
  ssid                     = var.wifi.ssid
  passphrase               = var.wifi.passphrase
  hardware_interface_name  = "wlan0"
  source_interface_name    = "phy0"
  bridge_interface_mtu     = each.value.hardware_interfaces.phy0.mtu
  hostapd_container_image  = local.config.container_images.hostapd
  static_pod_manifest_path = local.config.static_pod_manifest_path
  bssid                    = replace(each.value.hardware_interfaces.wlan0.mac, "-", ":")
  hostapd_mobility_domain  = random_id.hostapd_mobility_domain.hex
  hostapd_encryption_key   = random_id.hostapd_encryption_key.hex
  hostapd_roaming_members = [
    for host in values(local.aio_hostclass_config.hosts) :
    {
      name  = host.hostname
      bssid = replace(host.hardware_interfaces.wlan0.mac, "-", ":")
    }
  ]
}

module "template-aio-kubernetes_addons_manager" {
  for_each = local.aio_hostclass_config.hosts

  source                                = "./modules/kubernetes_addons"
  container_images                      = local.config.container_images
  apiserver_ip                          = cidrhost(local.config.networks.lan.prefix, local.aio_hostclass_config.vrrp_netnum)
  apiserver_port                        = local.config.ports.apiserver
  kubernetes_pod_network_prefix         = local.config.networks.kubernetes_pod.prefix
  kubernetes_service_network_prefix     = local.config.networks.kubernetes_service.prefix
  kubernetes_service_network_dns_netnum = local.config.kubernetes_service_network_dns_netnum
  flannel_host_gateway_interface_name   = "lan"
  kubernetes_cluster_name               = local.config.kubernetes_cluster_name
  kubernetes_cluster_domain             = local.config.domains.kubernetes
  internal_domain                       = local.config.domains.internal
  kubernetes_common_certs               = module.kubernetes-common.certs.kubernetes
  kubernetes_ca                         = module.kubernetes-common.ca.kubernetes
  static_pod_manifest_path              = local.config.static_pod_manifest_path
  internal_dns_ip                       = cidrhost(local.config.networks.lan.prefix, local.aio_hostclass_config.vrrp_netnum)
  kubernetes_external_dns_ip = cidrhost(
    cidrsubnet(local.config.networks.lan.prefix, local.config.metallb_subnet.newbit, local.config.metallb_subnet.netnum),
    local.config.metallb_external_dns_netnum
  )
  metallb_network_prefix = local.config.networks.lan.prefix
  metallb_subnet         = local.config.metallb_subnet
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
    module.template-aio-minio[each.key].ignition_snippets,
    module.template-aio-hostapd[each.key].ignition_snippets,
    module.template-aio-kubernetes_addons_manager[each.key].ignition_snippets,
  )
}

resource "local_file" "aio" {
  for_each = local.aio_hostclass_config.hosts

  content  = data.ct_config.aio[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}