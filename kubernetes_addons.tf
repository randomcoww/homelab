# basic system addons #
module "addons-base" {
  source                                = "./modules/kubernetes_addons_base"
  container_images                      = local.container_images
  apiserver_ip                          = cidrhost(local.networks.lan.prefix, local.aio_hostclass_config.vrrp_netnum)
  apiserver_port                        = local.ports.apiserver
  kubernetes_cluster_name               = local.kubernetes.cluster_name
  kubernetes_pod_network_prefix         = local.networks.kubernetes_pod.prefix
  kubernetes_service_network_prefix     = local.networks.kubernetes_service.prefix
  kubernetes_service_network_dns_netnum = local.kubernetes.service_network_dns_netnum
  flannel_host_gateway_interface_name   = "lan"
  kubernetes_cluster_domain             = local.domains.kubernetes
  internal_domain                       = local.domains.internal
  internal_dns_ip                       = cidrhost(local.networks.lan.prefix, local.aio_hostclass_config.vrrp_netnum)
  kubernetes_external_dns_ip = cidrhost(
    cidrsubnet(local.networks.lan.prefix, local.kubernetes.metallb_subnet.newbit, local.kubernetes.metallb_subnet.netnum),
    local.kubernetes.metallb_external_dns_netnum
  )
  metallb_network_prefix = local.networks.lan.prefix
  metallb_subnet         = local.kubernetes.metallb_subnet
  kubernetes_minio_ip = cidrhost(
    cidrsubnet(local.networks.lan.prefix, local.kubernetes.metallb_subnet.newbit, local.kubernetes.metallb_subnet.netnum),
    local.kubernetes.metallb_minio_netnum
  )
  minio_port         = local.ports.minio
  minio_console_port = local.ports.minio_console
}

locals {
  remote_kubernetes_manifests = {
    "nvidia-device-plugins.yaml" = "https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.10.0/nvidia-device-plugin.yml"
    "metallb-namespace.yaml"     = "https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/namespace.yaml"
    "metallb.yaml"               = "https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/metallb.yaml"
  }
}

data "http" "remote-kubernetes-manifests" {
  for_each = local.remote_kubernetes_manifests
  url      = each.value
}

# matchbox pxeboot #
module "addons-pxeboot" {
  source                 = "./modules/kubernetes_addons_pxeboot"
  container_images       = local.container_images
  resource_name          = "pxeboot"
  pod_count              = 2
  allowed_network_prefix = local.networks.kubernetes_pod.prefix
  internal_pxeboot_ip = cidrhost(
    cidrsubnet(local.networks.lan.prefix, local.kubernetes.metallb_subnet.newbit, local.kubernetes.metallb_subnet.netnum),
    local.kubernetes.metallb_pxeboot_netnum
  )
  internal_pxeboot_http_port = local.ports.internal_pxeboot_http
  internal_pxeboot_api_port  = local.ports.internal_pxeboot_api
}

module "template-kubernetes-addons" {
  source               = "./modules/kubernetes_addons_parser"
  addon_manifests_path = local.kubernetes.addon_manifests_path
  addon_manifests = merge(
    module.addons-base.addon_manifests,
    module.addons-pxeboot.addon_manifests, {
      for file_name in keys(local.remote_kubernetes_manifests) :
      file_name => data.http.remote-kubernetes-manifests[file_name].body
  })
}