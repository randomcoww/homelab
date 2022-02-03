# templates #
module "template-client-base" {
  for_each = local.client_hostclass_config.hosts

  source   = "./modules/base"
  hostname = each.value.hostname
  users    = [local.users.client]
}

module "template-client-desktop" {
  for_each = local.client_hostclass_config.hosts

  source                    = "./modules/desktop"
  ssh_ca_public_key_openssh = module.ssh-server-common.ca.ssh.public_key_openssh
  hardware_interfaces       = each.value.hardware_interfaces
}

module "template-client-disks" {
  for_each = local.client_hostclass_config.hosts

  source = "./modules/disks"
  disks  = each.value.disks
}

# kubernetes #
module "template-client-kubelet" {
  for_each = local.client_hostclass_config.hosts

  source           = "./modules/kubelet"
  container_images = local.container_images
}

module "template-client-worker" {
  for_each = local.client_hostclass_config.hosts

  source                                = "./modules/worker"
  container_images                      = local.container_images
  common_certs                          = module.kubernetes-common.certs
  apiserver_ip                          = cidrhost(local.networks.lan.prefix, local.aio_hostclass_config.vrrp_netnum)
  apiserver_port                        = local.ports.apiserver
  kubelet_port                          = local.ports.kubelet
  kubernetes_cluster_name               = local.kubernetes.cluster_name
  kubernetes_cluster_domain             = local.domains.kubernetes
  kubernetes_service_network_prefix     = local.networks.kubernetes_service.prefix
  kubernetes_service_network_dns_netnum = local.kubernetes.service_network_dns_netnum
  kubelet_node_labels                   = {}
  container_storage_path                = each.value.container_storage_path
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
    module.template-client-kubelet[each.key].ignition_snippets,
    module.template-client-worker[each.key].ignition_snippets,
  )
}

resource "local_file" "client" {
  for_each = local.client_hostclass_config.hosts

  content  = data.ct_config.client[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}