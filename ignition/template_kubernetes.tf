module "kubernetes-master" {
  for_each = local.members.kubernetes-master
  source   = "./modules/kubernetes_master"

  butane_version  = local.butane_version
  fw_mark         = local.fw_marks.accept
  name            = "kube-master"
  cluster_name    = local.kubernetes.cluster_name
  front_proxy_ca  = data.terraform_remote_state.sr.outputs.kubernetes.front_proxy_ca
  kubernetes_ca   = data.terraform_remote_state.sr.outputs.kubernetes.ca
  etcd_ca         = data.terraform_remote_state.sr.outputs.etcd.ca
  service_account = data.terraform_remote_state.sr.outputs.kubernetes.service_account
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
  cluster_apiserver_endpoint = "${local.kubernetes_services.apiserver.endpoint}.svc.${local.domains.kubernetes}"
  kubernetes_service_prefix  = local.networks.kubernetes_service.prefix
  kubernetes_pod_prefix      = local.networks.kubernetes_pod.prefix
  node_ips = [
    for _, network in each.value.networks :
    cidrhost(network.prefix, each.value.netnum)
  ]
  apiserver_ip          = local.services.apiserver.ip
  cluster_apiserver_ip  = local.services.cluster_apiserver.ip
  static_pod_path       = local.kubernetes.static_pod_manifest_path
  bird_path             = local.ha.bird_config_path
  bird_cache_table_name = local.ha.bird_cache_table_name
  haproxy_path          = local.ha.haproxy_config_path
  bgp_port              = local.host_ports.bgp
  bgp_prefix            = each.value.networks.node.prefix
  bgp_as                = local.ha.bgp_as
  bgp_neighbor_netnums = {
    for host_key, host in local.members.gateway :
    host_key => host.netnum if each.key != host_key
  }
}

module "kubernetes-worker" {
  for_each = local.members.kubernetes-worker
  source   = "./modules/kubernetes_worker"

  butane_version            = local.butane_version
  fw_mark                   = local.fw_marks.accept
  name                      = "kube-worker"
  cluster_name              = local.kubernetes.cluster_name
  ca                        = data.terraform_remote_state.sr.outputs.kubernetes.ca
  kubelet_port              = local.host_ports.kubelet
  host_netnum               = each.value.netnum
  node_bootstrap_user       = local.kubernetes.node_bootstrap_user
  cluster_domain            = local.domains.kubernetes
  apiserver_endpoint        = "https://${local.services.apiserver.ip}:${local.host_ports.apiserver}"
  cni_bridge_interface_name = local.kubernetes.cni_bridge_interface_name
  kubernetes_pod_prefix     = local.networks.kubernetes_pod.prefix
  node_prefix               = each.value.networks.service.prefix
  cluster_dns_ip            = local.services.cluster_dns.ip
  kubelet_root_path         = local.kubernetes.kubelet_root_path
  static_pod_path           = local.kubernetes.static_pod_manifest_path
  cni_bin_path              = local.kubernetes.cni_bin_path
  container_storage_path    = "${local.kubernetes.containers_path}/storage"
  graceful_shutdown_delay   = 480
  registry_mirrors = {
    for key, registry in local.registry_mirrors :
    key => merge({
      for k, v in registry :
      k => v
      if k != "port"
      }, {
      mirror_location = "${local.services.cluster_registry_mirror.ip}:${registry.port}"
    })
  }
}

module "etcd" {
  for_each = local.members.etcd
  source   = "./modules/etcd_member"

  butane_version = local.butane_version
  fw_mark        = local.fw_marks.accept
  name           = local.kubernetes_services.etcd.name
  namespace      = local.kubernetes_services.etcd.namespace
  host_key       = each.key
  cluster_token  = local.kubernetes.cluster_name
  ca             = data.terraform_remote_state.sr.outputs.etcd.ca
  peer_ca        = data.terraform_remote_state.sr.outputs.etcd.peer_ca
  images = {
    etcd         = local.container_images.etcd
    etcd_wrapper = local.container_images.etcd_wrapper
  }
  ports = {
    etcd_client  = local.host_ports.etcd_client
    etcd_peer    = local.host_ports.etcd_peer
    etcd_metrics = local.host_ports.etcd_metrics
  }
  node_ip = cidrhost(local.networks.etcd.prefix, each.value.netnum)
  members = {
    for host_key, host in local.members.etcd :
    host_key => cidrhost(local.networks.etcd.prefix, host.netnum)
  }
  s3_endpoint          = data.terraform_remote_state.sr.outputs.r2_bucket.etcd.url
  s3_resource          = "${data.terraform_remote_state.sr.outputs.r2_bucket.etcd.bucket}/snapshot/${local.kubernetes.cluster_name}.db"
  s3_access_key_id     = data.terraform_remote_state.sr.outputs.r2_bucket.etcd.access_key_id
  s3_secret_access_key = data.terraform_remote_state.sr.outputs.r2_bucket.etcd.secret_access_key
  static_pod_path      = local.kubernetes.static_pod_manifest_path
}