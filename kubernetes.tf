locals {
  remote_kubernetes_manifests = {
    "nvidia-device-plugins.yaml" = "https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.10.0/nvidia-device-plugin.yml"
    "metallb-namespace.yaml"     = "https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/namespace.yaml"
    "metallb.yaml"               = "https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/metallb.yaml"
  }

  kubernetes_addons_manifests = merge({
    for file_name in keys(local.remote_kubernetes_manifests) :
    file_name => data.http.remote-kubernetes-manifests[file_name].body
    },
    module.template-kubernetes_addons_base.addon_manifests,
    module.template-kubernetes_addons_pxeboot.addon_manifests,
  )
}

data "http" "remote-kubernetes-manifests" {
  for_each = local.remote_kubernetes_manifests
  url      = each.value
}

# kubernetes #
module "etcd-common" {
  source = "./modules/etcd_common"

  s3_backup_bucket = "randomcoww-etcd-backup"
  s3_backup_key    = local.config.kubernetes_cluster_name
}

module "kubernetes-common" {
  source = "./modules/kubernetes_common"
}

# kubernetes addons #
module "template-kubernetes_addons_base" {
  source                                = "./modules/kubernetes_addons_base"
  container_images                      = local.config.container_images
  apiserver_ip                          = cidrhost(local.config.networks.lan.prefix, local.aio_hostclass_config.vrrp_netnum)
  apiserver_port                        = local.config.ports.apiserver
  kubernetes_cluster_name               = local.config.kubernetes_cluster_name
  kubernetes_pod_network_prefix         = local.config.networks.kubernetes_pod.prefix
  kubernetes_service_network_prefix     = local.config.networks.kubernetes_service.prefix
  kubernetes_service_network_dns_netnum = local.config.kubernetes_service_network_dns_netnum
  flannel_host_gateway_interface_name   = "lan"
  kubernetes_cluster_domain             = local.config.domains.kubernetes
  internal_domain                       = local.config.domains.internal
  internal_dns_ip                       = cidrhost(local.config.networks.lan.prefix, local.aio_hostclass_config.vrrp_netnum)
  kubernetes_external_dns_ip = cidrhost(
    cidrsubnet(local.config.networks.lan.prefix, local.config.metallb_subnet.newbit, local.config.metallb_subnet.netnum),
    local.config.metallb_external_dns_netnum
  )
  metallb_network_prefix = local.config.networks.lan.prefix
  metallb_subnet         = local.config.metallb_subnet
}

# matchbox deployment for kubernetes #
module "template-kubernetes_addons_pxeboot" {
  source                 = "./modules/kubernetes_addons_pxeboot"
  container_images       = local.config.container_images
  resource_name          = "pxeboot"
  pod_count              = 2
  allowed_network_prefix = local.config.networks.kubernetes_pod.prefix
  internal_pxeboot_ip = (cidrhost(
    cidrsubnet(local.config.networks.lan.prefix, local.config.metallb_subnet.newbit, local.config.metallb_subnet.netnum),
    local.config.metallb_pxeboot_netnum
  ))
  internal_pxeboot_http_port = local.config.ports.internal_pxeboot_http
  internal_pxeboot_api_port  = local.config.ports.internal_pxeboot_api
}