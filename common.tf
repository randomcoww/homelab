module "etcd-cluster" {
  source = "./modules/etcd_cluster"

  cluster_token = "aio-prod-3"
  cluster_hosts = [
    for host_key in [
      "aio-0",
    ] :
    {
      hostname    = local.hosts[host_key].hostname
      ip          = cidrhost(local.networks.lan.prefix, local.hosts[host_key].netnum)
      client_port = local.ports.etcd_client
      peer_port   = local.ports.etcd_peer
    }
  ]
  aws_region       = "us-west-2"
  s3_backup_bucket = "randomcoww-etcd-backup"
}

module "kubernetes-common" {
  source = "./modules/kubernetes_common"

  cluster_name           = "aio-prod-3"
  apiserver_vip          = local.networks.lan.vips.vrrp
  etcd_cluster_endpoints = module.etcd-cluster.cluster_endpoints
}



# module "ignition-gateway" {
#   for_each = {
#     for host_key in [
#       "aio-0",
#     ] :
#     host_key => local.hosts[host_key]
#   }

#   source             = "./modules/gateway"
#   hostname           = each.value.hostname
#   user               = local.users.admin
#   interfaces         = module.ignition-systemd-networkd[each.key].interfaces
#   container_images   = local.container_images
#   dhcp_server_subnet = local.dhcp_server_subnet
#   kea_peer_port      = local.ports.kea_peer
#   host_netnum        = each.value.netnum
#   vrrp_netnum        = each.value.vrrp_netnum
#   kea_peers = [
#     for i, host in [
#       local.hosts.aio-0,
#       local.hosts.client-0,
#     ] :
#     {
#       name   = host.hostname
#       netnum = host.netnum
#       role   = try(element(["primary", "secondary"], i), "backup")
#     }
#   ]
#   internal_dns_ip = cidrhost(
#     cidrsubnet(local.networks.lan.prefix, local.kubernetes.metallb_subnet.newbit, local.kubernetes.metallb_subnet.netnum),
#     local.kubernetes.metallb_external_dns_netnum
#   )
#   internal_domain = local.domains.internal
#   pxeboot_file_name = "http://${cidrhost(
#     cidrsubnet(local.networks.lan.prefix, local.kubernetes.metallb_subnet.newbit, local.kubernetes.metallb_subnet.netnum),
#     local.kubernetes.metallb_pxeboot_netnum
#   )}:${local.ports.internal_pxeboot_http}/boot.ipxe"
#   static_pod_manifest_path = local.kubernetes.static_pod_manifest_path
# }





# module "ignition-kubernetes-worker" {
#   for_each = {
#     for host_key in [
#       "aio-0",
#       "client-0",
#     ] :
#     host_key => local.hosts[host_key]
#   }

#   source                                = "./modules/worker"
#   container_images                      = local.container_images
#   common_certs                          = module.kubernetes-common.certs
#   apiserver_ip                          = "127.0.0.1"
#   apiserver_port                        = local.ports.apiserver
#   kubelet_port                          = local.ports.kubelet
#   kubernetes_cluster_name               = local.kubernetes.cluster_name
#   kubernetes_cluster_domain             = local.domains.kubernetes
#   kubernetes_service_network_prefix     = local.networks.kubernetes_service.prefix
#   kubernetes_service_network_dns_netnum = local.kubernetes.service_network_dns_netnum
#   kubelet_node_labels                   = {}
#   static_pod_manifest_path              = local.kubernetes.static_pod_manifest_path
#   container_storage_path                = each.value.container_storage_path
# }

# module "ignition-minio" {
#   for_each = {
#     for host_key in [
#       "aio-0",
#     ] :
#     host_key => local.hosts[host_key]
#   }

#   source                   = "./modules/minio"
#   minio_container_image    = local.container_images.minio
#   minio_port               = local.ports.minio
#   minio_console_port       = local.ports.minio_console
#   volume_paths             = each.value.minio_volume_paths
#   static_pod_manifest_path = local.kubernetes.static_pod_manifest_path
#   minio_credentials = {
#     access_key_id     = random_password.minio-access-key-id.result
#     secret_access_key = random_password.minio-secret-access-key.result
#   }
# }