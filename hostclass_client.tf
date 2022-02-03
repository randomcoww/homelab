locals {
  client_hostclass_config = {
    vrrp_netnum = 2
    hosts = {
      client-0 = merge(local.host_spec.client-laptop, {
        hostname = "client-0.${local.domains.internal_mdns}"
        tap_interfaces = {
          lan = {
            source_interface_name = "phy0"
            enable_mdns           = true
            enable_netnum         = true
            enable_vrrp_netnum    = true
            enable_dhcp_server    = true
            mtu                   = 9000
          }
        }
      })
    }
  }
}

# templates #
module "template-client-base" {
  for_each = local.client_hostclass_config.hosts

  source   = "./modules/base"
  hostname = each.value.hostname
  users    = [local.users.client]
}

module "template-client-server" {
  for_each = local.client_hostclass_config.hosts

  source              = "./modules/server"
  networks            = local.networks
  hardware_interfaces = each.value.hardware_interfaces
  tap_interfaces      = each.value.tap_interfaces
  host_netnum         = each.value.netnum
}

module "template-client-disks" {
  for_each = local.client_hostclass_config.hosts

  source = "./modules/disks"
  disks  = each.value.disks
}

module "template-client-ssh_server" {
  for_each = local.client_hostclass_config.hosts

  source     = "./modules/ssh_server"
  key_id     = each.value.hostname
  user_names = [local.users.admin.name]
  valid_principals = compact(concat([each.value.hostname, "127.0.0.1"], flatten([
    for interface in values(module.template-client-server[each.key].interfaces) :
    try(cidrhost(interface.prefix, each.value.netnum), null)
    if lookup(interface, "enable_netnum", false)
  ])))
  ssh_ca = module.ssh-server-common.ca.ssh
}

module "template-client-hypervisor" {
  for_each = local.client_hostclass_config.hosts

  source    = "./modules/hypervisor"
  dns_names = [each.value.hostname]
  ip_addresses = compact(concat(["127.0.0.1"], flatten([
    for interface in values(module.template-client-server[each.key].interfaces) :
    try(cidrhost(interface.prefix, each.value.netnum), null)
    if lookup(interface, "enable_netnum", false)
  ])))
  libvirt_ca = module.hypervisor-common.ca.libvirt
}

# kubernetes #
module "template-client-kubelet" {
  for_each = local.client_hostclass_config.hosts

  source                   = "./modules/kubelet"
  container_images         = local.container_images
  network_prefix           = local.networks.lan.prefix
  host_netnum              = each.value.netnum
  static_pod_manifest_path = local.kubernetes.static_pod_manifest_path
}

module "template-client-worker" {
  for_each = local.client_hostclass_config.hosts

  source                                = "./modules/worker"
  container_images                      = local.container_images
  common_certs                          = module.kubernetes-common.certs
  apiserver_ip                          = cidrhost(local.networks.lan.prefix, local.client_hostclass_config.vrrp_netnum)
  apiserver_port                        = local.ports.apiserver
  kubelet_port                          = local.ports.kubelet
  kubernetes_cluster_name               = local.kubernetes.cluster_name
  kubernetes_cluster_domain             = local.domains.kubernetes
  kubernetes_service_network_prefix     = local.networks.kubernetes_service.prefix
  kubernetes_service_network_dns_netnum = local.kubernetes.service_network_dns_netnum
  kubelet_node_labels                   = {}
  container_storage_path                = each.value.container_storage_path
}

module "template-client-desktop" {
  for_each = local.client_hostclass_config.hosts

  source                    = "./modules/desktop"
  ssh_ca_public_key_openssh = module.ssh-server-common.ca.ssh.public_key_openssh
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
    module.template-client-disks[each.key].ignition_snippets,
    module.template-client-kubelet[each.key].ignition_snippets,
    module.template-client-worker[each.key].ignition_snippets,
    module.template-client-desktop[each.key].ignition_snippets,
  )
}

resource "local_file" "client" {
  for_each = local.client_hostclass_config.hosts

  content  = data.ct_config.client[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}