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

# Nvidia container toolkit for Kubernetes GPU access

module "nvidia-container" {
  for_each = local.members.nvidia-container
  source   = "./modules/nvidia_container"

  ignition_version = local.ignition_version
}