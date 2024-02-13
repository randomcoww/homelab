module "base" {
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
}

# disk #

module "disks" {
  for_each = local.members.disks
  source   = "./modules/disks"

  ignition_version = local.ignition_version
  disks            = lookup(each.value, "disks", {})
}

module "mounts" {
  for_each = local.members.mounts
  source   = "./modules/mounts"

  ignition_version = local.ignition_version
  mounts           = lookup(each.value, "mounts", [])
}

# network #

module "vrrp" {
  for_each = local.members.vrrp
  source   = "./modules/vrrp"

  ignition_version = local.ignition_version
  haproxy_path     = local.vrrp.haproxy_config_path
  keepalived_path  = local.vrrp.keepalived_config_path
}

module "gateway" {
  for_each = local.members.gateway
  source   = "./modules/gateway"

  ignition_version = local.ignition_version
  name             = "gateway"
  host_netnum      = each.value.netnum
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

module "systemd-networkd" {
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

module "network-manager" {
  for_each         = local.members.network-manager
  source           = "./modules/network_manager"
  ignition_version = local.ignition_version
}

module "upstream-dns" {
  for_each         = local.members.upstream-dns
  source           = "./modules/upstream_dns"
  ignition_version = local.ignition_version
  upstream_dns     = local.upstream_dns
}

module "server" {
  for_each = local.members.server
  source   = "./modules/server"

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
  ca = data.terraform_remote_state.sr.outputs.ssh.ca
}

module "client" {
  for_each = local.members.client
  source   = "./modules/client"

  ignition_version   = local.ignition_version
  public_key_openssh = data.terraform_remote_state.sr.outputs.ssh.ca.public_key_openssh
}

# kubernetes #

module "kubernetes-master" {
  for_each = local.members.kubernetes-master
  source   = "./modules/kubernetes_master"

  ignition_version = local.ignition_version
  name             = "kubernetes-master"
  cluster_name     = local.kubernetes.cluster_name
  front_proxy_ca   = data.terraform_remote_state.sr.outputs.kubernetes.front_proxy_ca
  kubernetes_ca    = data.terraform_remote_state.sr.outputs.kubernetes.ca
  etcd_ca          = data.terraform_remote_state.sr.outputs.etcd.ca
  service_account  = data.terraform_remote_state.sr.outputs.kubernetes.service_account
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
    apiserver          = local.host_ports.apiserver
    apiserver_backend  = local.host_ports.apiserver_backend
    controller_manager = local.host_ports.controller_manager
    scheduler          = local.host_ports.scheduler
    etcd_client        = local.host_ports.etcd_client
  }
  kubelet_client_user        = local.kubernetes.kubelet_client_user
  front_proxy_client_user    = local.kubernetes.front_proxy_client_user
  cluster_apiserver_endpoint = local.kubernetes_services.apiserver.fqdn
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

module "kubernetes-worker" {
  for_each = local.members.kubernetes-worker
  source   = "./modules/kubernetes_worker"

  ignition_version = local.ignition_version
  name             = "kubernetes-worker"
  cluster_name     = local.kubernetes.cluster_name
  ca               = data.terraform_remote_state.sr.outputs.kubernetes.ca
  ports = {
    kubelet = local.host_ports.kubelet
  }
  node_bootstrap_user       = local.kubernetes.node_bootstrap_user
  cluster_domain            = local.domains.kubernetes
  apiserver_endpoint        = "https://${local.services.apiserver.ip}:${local.host_ports.apiserver}"
  cni_bridge_interface_name = local.kubernetes.cni_bridge_interface_name
  node_ip                   = cidrhost(local.networks.kubernetes.prefix, each.value.netnum)
  cluster_dns_ip            = local.services.cluster_dns.ip
  kubelet_root_path         = local.kubernetes.kubelet_root_path
  static_pod_path           = local.kubernetes.static_pod_manifest_path
  container_storage_path    = "${local.mounts.containers_path}/storage"
  graceful_shutdown_delay   = 480
}

module "etcd" {
  for_each = local.members.etcd
  source   = "./modules/etcd_member"

  ignition_version = local.ignition_version
  name             = "etcd"
  host_key         = each.key
  cluster_token    = local.kubernetes.cluster_name
  ca               = data.terraform_remote_state.sr.outputs.etcd.ca
  peer_ca          = data.terraform_remote_state.sr.outputs.etcd.peer_ca
  images = {
    etcd         = local.container_images.etcd
    etcd_wrapper = local.container_images.etcd_wrapper
  }
  ports = {
    etcd_client = local.host_ports.etcd_client
    etcd_peer   = local.host_ports.etcd_peer
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

module "nvidia-container" {
  for_each = local.members.nvidia-container
  source   = "./modules/nvidia_container"

  ignition_version = local.ignition_version
}

# desktop environment #

module "desktop-environment" {
  for_each = local.members.desktop-environment
  source   = "./modules/desktop_environment"

  ignition_version = local.ignition_version
}

module "sunshine" {
  for_each = local.members.sunshine
  source   = "./modules/sunshine"

  ignition_version = local.ignition_version
  sunshine_config = {
    key_rightalt_to_key_win = "enabled"
    origin_web_ui_allowed   = "pc"
  }
}

# remote access #

module "remote" {
  for_each = local.members.remote
  source   = "./modules/remote"

  ignition_version      = local.ignition_version
  ssm_access_key_id     = data.terraform_remote_state.sr.outputs.ssm.tailscale.access_key_id
  ssm_secret_access_key = data.terraform_remote_state.sr.outputs.ssm.tailscale.secret_access_key
  ssm_resource          = data.terraform_remote_state.sr.outputs.ssm.tailscale.resource
  ssm_region            = data.terraform_remote_state.sr.outputs.ssm.tailscale.aws_region
}

locals {
  modules_enabled = [
    module.base,
    module.systemd-networkd,
    module.network-manager,
    module.upstream-dns,
    module.gateway,
    module.vrrp,
    module.disks,
    module.mounts,
    module.etcd,
    module.kubernetes-master,
    module.kubernetes-worker,
    module.nvidia-container,
    module.server,
    module.client,
    module.desktop-environment,
    module.sunshine,
    module.remote,
  ]
}

# render ignition to output and local files

data "ct_config" "ignition" {
  for_each = {
    for host_key in keys(local.hosts) :
    host_key => flatten([
      for m in local.modules_enabled :
      try(m[host_key].ignition_snippets, [])
    ])
  }
  content = yamlencode({
    variant = "fcos"
    version = local.ignition_version
  })
  strict   = true
  snippets = sort(each.value)
}