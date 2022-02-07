module "ignition-base" {
  for_each = {
    for host_key in [
      "aio-0",
    ] :
    host_key => local.hosts[host_key]
  }

  source   = "./modules/base"
  hostname = each.value.hostname
  users    = [local.users.admin]
}

module "ignition-systemd-networkd" {
  for_each = {
    for host_key in [
      "aio-0",
    ] :
    host_key => local.hosts[host_key]
  }

  source              = "./modules/systemd_networkd"
  host_netnum         = each.value.netnum
  hardware_interfaces = each.value.hardware_interfaces
  bridge_interfaces   = each.value.bridge_interfaces
  tap_interfaces      = each.value.tap_interfaces
  networks            = local.networks
}

module "ignition-disks" {
  for_each = {
    for host_key in [
      "aio-0",
    ] :
    host_key => local.hosts[host_key]
  }

  source = "./modules/disks"
  disks  = each.value.disks
}

# masterless kubelet
module "ignition-kubelet-base" {
  for_each = {
    for host_key in [
      "aio-0",
    ] :
    host_key => local.hosts[host_key]
  }

  source                   = "./modules/kubelet_base"
  node_ip                  = cidrhost(local.networks.lan.prefix, each.value.netnum)
  static_pod_manifest_path = local.kubernetes.static_pod_manifest_path
}

module "ignition-etcd" {
  for_each = module.etcd-cluster.member_template_params

  source                       = "./modules/etcd_member"
  ca                           = module.etcd-cluster.ca
  peer_ca                      = module.etcd-cluster.peer_ca
  certs                        = module.etcd-cluster.certs
  template_params              = each.value
  etcd_container_image         = local.container_images.etcd
  etcd_wrapper_container_image = local.container_images.etcd_wrapper
  static_pod_manifest_path     = local.kubernetes.static_pod_manifest_path
}

module "ignition-kubernetes-master" {
  for_each = {
    for host_key in [
      "aio-0",
    ] :
    host_key => local.hosts[host_key]
  }

  source                   = "./modules/kubernetes_master"
  ca                       = module.kubernetes-common.ca
  etcd_ca                  = module.etcd-cluster.ca
  certs                    = module.kubernetes-common.certs
  etcd_certs               = module.etcd-cluster.certs
  template_params          = module.kubernetes-common.template_params
  addon_manifests_path     = local.kubernetes.addon_manifests_path
  static_pod_manifest_path = local.kubernetes.static_pod_manifest_path
}

module "ignition-kubernetes-worker" {
  for_each = {
    for host_key in [
      "aio-0",
    ] :
    host_key => local.hosts[host_key]
  }

  source                   = "./modules/kubernetes_worker"
  ca                       = module.kubernetes-common.ca
  certs                    = module.kubernetes-common.certs
  template_params          = module.kubernetes-common.template_params
  kubelet_node_labels      = {}
  container_storage_path   = each.value.container_storage_path
  static_pod_manifest_path = local.kubernetes.static_pod_manifest_path
}

module "ignition-hypervisor" {
  for_each = {
    for host_key in [
      "aio-0",
    ] :
    host_key => local.hosts[host_key]
  }

  source       = "./modules/hypervisor_server"
  ca           = module.hypervisor-common.ca
  certs        = module.hypervisor-common.certs
  ip_addresses = [cidrhost(local.networks.lan.prefix, each.value.netnum)]
  dns_names    = [each.value.hostname]
}

module "ignition-ssh-server" {
  for_each = {
    for host_key in [
      "aio-0",
    ] :
    host_key => local.hosts[host_key]
  }

  source     = "./modules/ssh_server"
  key_id     = each.value.hostname
  user_names = [local.users.admin.name]
  valid_principals = [
    each.value.hostname,
    "127.0.0.1",
    cidrhost(local.networks.lan.prefix, each.value.netnum),
  ]
  ca = module.ssh-common.ca
}

module "ignition-hostapd" {
  for_each = module.hostapd-common.template_params

  source          = "./modules/hostapd"
  template_params = each.value
}


# combine and render a single ignition file #
data "ct_config" "ignition" {
  for_each = {
    for host_key in keys(local.hosts) :
    host_key => flatten([
      try(module.ignition-base[host_key].ignition_snippets, []),
      try(module.ignition-systemd-networkd[host_key].ignition_snippets, []),
      try(module.ignition-disks[host_key].ignition_snippets, []),
      try(module.ignition-kubelet-base[host_key].ignition_snippets, []),
      try(module.ignition-etcd[host_key].ignition_snippets, []),
      try(module.ignition-kubernetes-master[host_key].ignition_snippets, []),
      try(module.ignition-kubernetes-worker[host_key].ignition_snippets, []),
      try(module.ignition-ssh-server[host_key].ignition_snippets, []),
      try(module.ignition-hypervisor[host_key].ignition_snippets, []),
      try(module.ignition-hostapd[host_key].ignition_snippets, []),

      # try(module.ignition-gateway[host_key].ignition_snippets, []),
      # try(module.ignition-minio[host_key].ignition_snippets, []),
    ])
  }
  content  = <<EOT
---
variant: fcos
version: 1.4.0
EOT
  strict   = true
  snippets = each.value
}

resource "local_file" "ignition" {
  for_each = local.hosts

  content  = data.ct_config.ignition[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}