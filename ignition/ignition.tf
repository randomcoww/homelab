module "ignition-base" {
  for_each = local.members.base
  source   = "./modules/base"

  ignition_version = local.ignition_version
  hostname         = each.value.hostname
  users = [
    for user_key in each.value.users :
    merge(local.users, {
      for type, user in local.users :
      type => merge(
        user,
        lookup(var.users, type, {}),
      )
    })[user_key]
  ]
  upstream_dns = local.upstream_dns
}

# disk #

module "ignition-disks" {
  for_each = local.members.disks
  source   = "./modules/disks"

  ignition_version = local.ignition_version
  disks            = lookup(each.value, "disks", {})
}

module "ignition-mounts" {
  for_each = local.members.mounts
  source   = "./modules/mounts"

  ignition_version = local.ignition_version
  mounts           = lookup(each.value, "mounts", [])
}

# network #

module "ignition-vrrp" {
  for_each = local.members.vrrp
  source   = "./modules/vrrp"

  ignition_version = local.ignition_version
  haproxy_path     = local.vrrp.haproxy_config_path
  keepalived_path  = local.vrrp.keepalived_config_path
}

module "ignition-gateway" {
  for_each = local.members.gateway
  source   = "./modules/gateway"

  ignition_version = local.ignition_version
  name             = "gateway"
  host_netnum      = each.value.netnum
  ports = {
    gateway_dns = local.ports.gateway_dns
  }
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
  lan_interface_name  = each.value.tap_interfaces[local.services.gateway.network.name].interface_name
  lan_prefix          = local.services.gateway.network.prefix
  sync_prefix         = local.networks.sync.prefix
  lan_gateway_ip      = local.services.gateway.ip
  virtual_router_id   = 10
  keepalived_path     = local.vrrp.keepalived_config_path
}

module "ignition-systemd-networkd" {
  for_each = local.members.systemd-networkd
  source   = "./modules/systemd_networkd"

  ignition_version    = local.ignition_version
  host_netnum         = each.value.netnum
  physical_interfaces = lookup(each.value, "physical_interfaces", {})
  bridge_interfaces   = lookup(each.value, "bridge_interfaces", {})
  virtual_interfaces  = lookup(each.value, "virtual_interfaces", {})
  wlan_interfaces     = lookup(each.value, "wlan_interfaces", {})
  tap_interfaces      = lookup(each.value, "tap_interfaces", {})
}

module "ignition-network-manager" {
  for_each         = local.members.network-manager
  source           = "./modules/network_manager"
  ignition_version = local.ignition_version
}

# kubernetes #

module "ignition-kubernetes-master" {
  for_each = local.members.kubernetes-master
  source   = "./modules/kubernetes_master"

  ignition_version = local.ignition_version
  name             = "kubernetes-master"
  cluster_name     = local.kubernetes.cluster_name
  ca               = data.terraform_remote_state.sr.outputs.kubernetes_ca
  etcd_ca          = data.terraform_remote_state.sr.outputs.etcd_ca
  service_account  = data.terraform_remote_state.sr.outputs.kubernetes_service_account
  members = {
    for host_key, host in local.members.kubernetes-master :
    host_key => cidrhost(local.networks.kubernetes.prefix, host.netnum)
  }
  etcd_members = {
    for host_key, host in local.members.etcd :
    host_key => cidrhost(local.networks.etcd.prefix, host.netnum)
  }
  images = {
    apiserver          = local.container_images.kube_apiserver
    controller_manager = local.container_images.kube_controller_manager
    scheduler          = local.container_images.kube_scheduler
  }
  ports = {
    apiserver          = local.ports.apiserver
    apiserver_backend  = local.ports.apiserver_backend
    controller_manager = local.ports.controller_manager
    scheduler          = local.ports.scheduler
    etcd_client        = local.ports.etcd_client
  }
  kubelet_access_user        = local.kubernetes.kubelet_access_user
  cluster_apiserver_endpoint = local.kubernetes_service_endpoints.apiserver
  kubernetes_service_prefix  = local.networks.kubernetes_service.prefix
  kubernetes_pod_prefix      = local.networks.kubernetes_pod.prefix
  apiserver_interface_name   = each.value.tap_interfaces[local.services.apiserver.network.name].interface_name
  sync_interface_name        = each.value.tap_interfaces.sync.interface_name
  node_ip                    = cidrhost(local.networks.kubernetes.prefix, each.value.netnum)
  apiserver_ip               = local.services.apiserver.ip
  cluster_apiserver_ip       = local.services.cluster_apiserver.ip
  virtual_router_id          = 11
  static_pod_path            = local.kubernetes.static_pod_manifest_path
  haproxy_path               = local.vrrp.haproxy_config_path
  keepalived_path            = local.vrrp.keepalived_config_path
}

module "ignition-kubernetes-worker" {
  for_each = local.members.kubernetes-worker
  source   = "./modules/kubernetes_worker"

  ignition_version = local.ignition_version
  name             = "kubernetes-worker"
  cluster_name     = local.kubernetes.cluster_name
  ca               = data.terraform_remote_state.sr.outputs.kubernetes_ca
  ports = {
    kubelet = local.ports.kubelet
  }
  node_bootstrap_user       = local.kubernetes.node_bootstrap_user
  cluster_domain            = local.domains.kubernetes
  apiserver_endpoint        = "https://${local.services.apiserver.ip}:${local.ports.apiserver}"
  cni_bridge_interface_name = local.kubernetes.cni_bridge_interface_name
  node_ip                   = cidrhost(local.networks.kubernetes.prefix, each.value.netnum)
  cluster_dns_ip            = local.services.cluster_dns.ip
  kubelet_root_path         = local.kubernetes.kubelet_root_path
  static_pod_path           = local.kubernetes.static_pod_manifest_path
  container_storage_path    = "${local.mounts.containers_path}/storage"
}

module "ignition-etcd" {
  for_each = local.members.etcd
  source   = "./modules/etcd_member"

  ignition_version = local.ignition_version
  name             = "etcd"
  host_key         = each.key
  cluster_token    = local.kubernetes.cluster_name
  ca               = data.terraform_remote_state.sr.outputs.etcd_ca
  peer_ca          = data.terraform_remote_state.sr.outputs.etcd_peer_ca
  images = {
    etcd         = local.container_images.etcd
    etcd_wrapper = local.container_images.etcd_wrapper
  }
  ports = {
    etcd_client = local.ports.etcd_client
    etcd_peer   = local.ports.etcd_peer
  }

  members = {
    for host_key, host in local.members.etcd :
    host_key => cidrhost(local.networks.etcd.prefix, host.netnum)
  }
  etcd_ips = sort([
    cidrhost(local.networks.etcd.prefix, each.value.netnum)
  ])
  s3_resource          = "${data.terraform_remote_state.sr.outputs.s3.etcd.resource}/${local.kubernetes.cluster_name}.db"
  s3_access_key_id     = data.terraform_remote_state.sr.outputs.s3.etcd.access_key_id
  s3_secret_access_key = data.terraform_remote_state.sr.outputs.s3.etcd.secret_access_key
  s3_region            = data.terraform_remote_state.sr.outputs.s3.etcd.aws_region
  static_pod_path      = local.kubernetes.static_pod_manifest_path
}

module "ignition-nvidia-container" {
  for_each = local.members.nvidia-container
  source   = "./modules/nvidia_container"

  ignition_version = local.ignition_version
}

# SSH CA #

module "ignition-ssh-server" {
  for_each = local.members.ssh-server
  source   = "./modules/ssh_server"

  ignition_version = local.ignition_version
  key_id           = each.value.hostname
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

  ignition_version   = local.ignition_version
  public_key_openssh = data.terraform_remote_state.sr.outputs.ssh_ca.public_key_openssh
}

# desktop environment #

module "ignition-desktop" {
  for_each = local.members.desktop
  source   = "./modules/desktop"

  ignition_version = local.ignition_version
}

module "ignition-sunshine" {
  for_each = local.members.sunshine
  source   = "./modules/sunshine"

  ignition_version = local.ignition_version
  sunshine_config = {
    key_rightalt_to_key_win = "enabled"
    origin_web_ui_allowed   = "pc"
  }
}

module "ignition-chromebook-hacks" {
  for_each = local.members.chromebook-hacks
  source   = "./modules/chromebook_hacks"

  ignition_version = local.ignition_version
}

# remote client #

module "ignition-remote" {
  for_each = local.members.remote
  source   = "./modules/remote"

  ignition_version      = local.ignition_version
  ssm_access_key_id     = data.terraform_remote_state.sr.outputs.ssm.tailscale.access_key_id
  ssm_secret_access_key = data.terraform_remote_state.sr.outputs.ssm.tailscale.secret_access_key
  ssm_resource          = data.terraform_remote_state.sr.outputs.ssm.tailscale.resource
  ssm_region            = data.terraform_remote_state.sr.outputs.ssm.tailscale.aws_region
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
  content  = <<-EOF
  ---
  variant: fcos
  version: ${local.ignition_version}
  EOF
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