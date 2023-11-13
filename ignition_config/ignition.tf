data "terraform_remote_state" "sr" {
  backend = "s3"
  config = {
    bucket = "randomcoww-tfstate"
    key    = local.states.cluster_resources
    region = local.aws_region
  }
}

# base system #

module "ignition-base" {
  for_each = local.members.base
  source   = "./modules/base"

  hostname = each.value.hostname
  users = [
    for user_key in each.value.users :
    local.users[user_key]
  ]
  upstream_dns = local.upstream_dns
}

module "ignition-systemd-networkd" {
  for_each = local.members.systemd-networkd
  source   = "./modules/systemd_networkd"

  host_netnum         = each.value.netnum
  hardware_interfaces = lookup(each.value, "hardware_interfaces", {})
  bridge_interfaces   = lookup(each.value, "bridge_interfaces", {})
  wlan_interfaces     = lookup(each.value, "wlan_interfaces", {})
  virtual_interfaces  = lookup(each.value, "virtual_interfaces", {})
  tap_interfaces      = lookup(each.value, "tap_interfaces", {})
}

module "ignition-network-manager" {
  for_each = local.members.network-manager
  source   = "./modules/network_manager"
}

module "ignition-kubelet-base" {
  for_each = local.members.kubelet-base
  source   = "./modules/kubelet_base"

  node_ip                  = try(cidrhost(local.networks.kubernetes.prefix, each.value.netnum), "")
  static_pod_manifest_path = local.kubernetes.static_pod_manifest_path
  container_storage_path   = "${local.mounts.containers_path}/storage"
}

module "ignition-gateway" {
  for_each = local.members.gateway
  source   = "./modules/gateway"

  container_images         = local.container_images
  host_netnum              = each.value.netnum
  static_pod_manifest_path = local.kubernetes.static_pod_manifest_path

  accept_prefixes = [
    local.networks.etcd.prefix,
    local.networks.sync.prefix,
    local.networks.lan.prefix,
    local.networks.kubernetes.prefix,
    local.networks.kubernetes_pod.prefix,
  ]
  forward_prefixes = [
    local.networks.lan.prefix,
    local.networks.kubernetes.prefix,
    local.networks.kubernetes_pod.prefix
  ]
  conntrackd_ignore_prefixes = sort(
    setsubtract(compact([
      for _, network in local.networks :
      try(network.prefix, "")
    ]), [local.services.gateway.network.prefix])
  )

  wan_interface_name  = each.value.tap_interfaces.wan.interface_name
  sync_interface_name = each.value.tap_interfaces.sync.interface_name
  sync_prefix         = local.networks.sync.prefix
  lan_interface_name  = each.value.tap_interfaces[local.services.gateway.network.name].interface_name
  lan_prefix          = local.services.gateway.network.prefix
  lan_vip             = local.services.gateway.ip
  internal_dns_vip    = local.services.external_dns.ip
}

module "ignition-vrrp" {
  for_each = local.members.vrrp
  source   = "./modules/vrrp"
}

module "ignition-disks" {
  for_each = local.members.disks
  source   = "./modules/disks"

  disks = lookup(each.value, "disks", {})
}

module "ignition-mounts" {
  for_each = local.members.mounts
  source   = "./modules/mounts"

  mounts = lookup(each.value, "mounts", [])
}

# SSH CA #

module "ignition-ssh-server" {
  for_each = local.members.ssh-server
  source   = "./modules/ssh_server"

  key_id = each.value.hostname
  valid_principals = sort(concat([
    for _, network in each.value.networks :
    cidrhost(network.prefix, each.value.netnum)
    if lookup(network, "enable_netnum", false)
    ], [
    each.value.hostname,
    each.value.tailscale_hostname,
    "127.0.0.1",
  ]))
  ca = data.terraform_remote_state.sr.outputs.ssh_ca
}

module "ignition-ssh-client" {
  for_each = local.members.ssh-client
  source   = "./modules/ssh_client"

  public_key_openssh = data.terraform_remote_state.sr.outputs.ssh_ca.public_key_openssh
}

# etcd #

module "ignition-etcd" {
  for_each = local.members.etcd
  source   = "./modules/etcd_member"

  cluster_token = local.kubernetes.cluster_name
  name          = each.key
  ca            = data.terraform_remote_state.sr.outputs.etcd_ca
  peer_ca       = data.terraform_remote_state.sr.outputs.etcd_peer_ca
  cluster_members = {
    for host_key, host in local.members.etcd :
    host_key => cidrhost(local.networks.etcd.prefix, host.netnum)
  }
  listen_ips = sort([
    cidrhost(local.networks.etcd.prefix, each.value.netnum)
  ])
  client_port              = local.ports.etcd_client
  peer_port                = local.ports.etcd_peer
  s3_backup_resource       = data.terraform_remote_state.sr.outputs.s3.etcd
  static_pod_manifest_path = local.kubernetes.static_pod_manifest_path
  container_images         = local.container_images
}

# kubernetes #

module "ignition-kubernetes-master" {
  for_each = local.members.kubernetes-master
  source   = "./modules/kubernetes_master"

  # interfaces               = module.ignition-systemd-networkd[each.key].tap_interfaces
  cluster_name    = local.kubernetes.cluster_name
  ca              = data.terraform_remote_state.sr.outputs.kubernetes_ca
  etcd_ca         = data.terraform_remote_state.sr.outputs.etcd_ca
  service_account = data.terraform_remote_state.sr.outputs.kubernetes_service_account
  etcd_cluster_members = {
    for host_key, host in local.members.etcd :
    host_key => cidrhost(local.networks.etcd.prefix, host.netnum)
  }
  apiserver_listen_ips = sort([
    cidrhost(local.networks.kubernetes.prefix, each.value.netnum),
    local.services.apiserver.ip,
    local.services.cluster_apiserver.ip,
  ])
  cluster_apiserver_endpoint = local.kubernetes_service_endpoints.apiserver
  cluster_members = {
    for host_key, host in local.members.kubernetes-master :
    host_key => cidrhost(local.networks.kubernetes.prefix, host.netnum)
  }
  static_pod_manifest_path = local.kubernetes.static_pod_manifest_path
  container_images         = local.container_images

  kubernetes_service_prefix = local.networks.kubernetes_service.prefix
  kubernetes_pod_prefix     = local.networks.kubernetes_pod.prefix
  apiserver_port            = local.ports.apiserver
  apiserver_ha_port         = local.ports.apiserver_ha
  etcd_client_port          = local.ports.etcd_client
  controller_manager_port   = local.ports.controller_manager
  scheduler_port            = local.ports.scheduler

  sync_interface_name      = each.value.tap_interfaces.sync.interface_name
  apiserver_interface_name = each.value.tap_interfaces[local.services.apiserver.network.name].interface_name
  apiserver_vip            = local.services.apiserver.ip
}

module "ignition-kubernetes-worker" {
  for_each = local.members.kubernetes-worker
  source   = "./modules/kubernetes_worker"

  cluster_name              = local.kubernetes.cluster_name
  ca                        = data.terraform_remote_state.sr.outputs.kubernetes_ca
  node_labels               = lookup(each.value, "kubernetes_worker_labels", {})
  node_taints               = lookup(each.value, "kubernetes_worker_taints", [])
  cni_bridge_interface_name = local.kubernetes.cni_bridge_interface_name
  apiserver_endpoint        = "https://${local.services.apiserver.ip}:${local.ports.apiserver_ha}"
  cluster_dns_ip            = local.services.cluster_dns.ip
  cluster_domain            = local.domains.kubernetes
  static_pod_manifest_path  = local.kubernetes.static_pod_manifest_path
  kubelet_port              = local.ports.kubelet
}

module "ignition-nvidia-container" {
  for_each = local.members.nvidia-container
  source   = "./modules/nvidia_container"
}

# client desktop environment #

module "ignition-desktop" {
  for_each = local.members.desktop
  source   = "./modules/desktop"
}

module "ignition-sunshine" {
  for_each = local.members.sunshine
  source   = "./modules/sunshine"
}

# remote client #

module "ignition-remote" {
  for_each = local.members.remote
  source   = "./modules/remote"

  wlan_interface       = "wlan0"
  tailscale_ssm_access = data.terraform_remote_state.sr.outputs.ssm.tailscale
}

# chromebook hacks #

module "ignition-chromebook-hacks" {
  for_each = local.members.chromebook-hacks
  source   = "./modules/chromebook_hacks"
}

# Render all

data "ct_config" "ignition" {
  for_each = {
    for host_key in keys(local.hosts) :
    host_key => flatten([
      try(module.ignition-base[host_key].ignition_snippets, []),
      try(module.ignition-systemd-networkd[host_key].ignition_snippets, []),
      try(module.ignition-network-manager[host_key].ignition_snippets, []),
      try(module.ignition-gateway[host_key].ignition_snippets, []),
      try(module.ignition-vrrp[host_key].ignition_snippets, []),
      try(module.ignition-disks[host_key].ignition_snippets, []),
      try(module.ignition-mounts[host_key].ignition_snippets, []),
      try(module.ignition-kubelet-base[host_key].ignition_snippets, []),
      try(module.ignition-etcd[host_key].ignition_snippets, []),
      try(module.ignition-kubernetes-master[host_key].ignition_snippets, []),
      try(module.ignition-kubernetes-worker[host_key].ignition_snippets, []),
      try(module.ignition-nvidia-container[host_key].ignition_snippets, []),
      try(module.ignition-ssh-server[host_key].ignition_snippets, []),
      try(module.ignition-ssh-client[host_key].ignition_snippets, []),
      try(module.ignition-desktop[host_key].ignition_snippets, []),
      try(module.ignition-sunshine[host_key].ignition_snippets, []),
      try(module.ignition-remote[host_key].ignition_snippets, []),
      try(module.ignition-chromebook-hacks[host_key].ignition_snippets, []),
    ])
  }
  content  = <<EOT
---
variant: fcos
version: 1.5.0
EOT
  strict   = true
  snippets = each.value
}

# Outputs

output "ignition" {
  value = {
    for host_key, content in data.ct_config.ignition :
    host_key => content.rendered
  }
  sensitive = true
}

# Write local files so that PXE update can work during outage

resource "local_file" "ignition" {
  for_each = local.hosts

  content  = data.ct_config.ignition[each.key].rendered
  filename = "${path.module}/output/ignition/${each.key}.ign"
}