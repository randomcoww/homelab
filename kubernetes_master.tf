# # kubernetes #
# module "etcd-common" {
#   source = "./modules/etcd_common"
#   s3_backup_bucket = "randomcoww-etcd-backup"
#   s3_backup_key    = local.kubernetes.cluster_name
# }

# module "template-aio-etcd" {
#   for_each = {
#     "aio-0" = local.hosts.aio-0
#   }

#   source           = "./modules/etcd"
#   hostname         = each.value.hostname
#   container_images = local.container_images
#   common_certs     = module.etcd-common.certs
#   network_prefix   = local.networks.lan.prefix
#   host_netnum      = each.value.netnum
#   etcd_hosts = [
#     for host in [
#       local.hosts.aio-0
#     ] :
#     {
#       name   = host.hostname
#       netnum = host.netnum
#     }
#   ]
#   etcd_client_port         = local.ports.etcd_client
#   etcd_peer_port           = local.ports.etcd_peer
#   etcd_cluster_token       = local.kubernetes.cluster_name
#   aws_access_key_id        = module.etcd-common.aws_user_access.id
#   aws_access_key_secret    = module.etcd-common.aws_user_access.secret
#   aws_region               = "us-west-2"
#   s3_backup_path           = module.etcd-common.s3_backup_path
#   etcd_ca                  = module.etcd-common.ca.etcd
#   static_pod_manifest_path = local.kubernetes.static_pod_manifest_path
# }

# module "kubernetes-common" {
#   source = "./modules/kubernetes_common"
# }

# module "template-aio-kubernetes" {
#   for_each = {
#     "aio-0" = local.hosts.aio-0
#   }

#   source                                      = "./modules/kubernetes"
#   hostname                                    = each.value.hostname
#   container_images                            = local.container_images
#   kubernetes_common_certs                     = module.kubernetes-common.certs.kubernetes
#   etcd_common_certs                           = module.etcd-common.certs.etcd
#   network_prefix                              = local.networks.lan.prefix
#   host_netnum                                 = each.value.netnum
#   vip_netnum                                  = local.aio_hostclass_config.vrrp_netnum
#   apiserver_port                              = local.ports.apiserver
#   controller_manager_port                     = local.ports.controller_manager
#   scheduler_port                              = local.ports.scheduler
#   etcd_client_port                            = local.ports.etcd_client
#   etcd_servers                                = [module.template-aio-etcd[each.key].local_client_endpoint]
#   kubernetes_cluster_name                     = local.kubernetes.cluster_name
#   kubernetes_service_network_prefix           = local.networks.kubernetes_service.prefix
#   kubernetes_pod_network_prefix               = local.networks.kubernetes_pod.prefix
#   kubernetes_service_network_apiserver_netnum = local.kubernetes.service_network_apiserver_netnum
#   encryption_config_secret                    = module.kubernetes-common.encryption_config_secret
#   kubernetes_ca                               = module.kubernetes-common.ca.kubernetes
#   static_pod_manifest_path                    = local.kubernetes.static_pod_manifest_path
#   addon_manifests_path                        = local.kubernetes.addon_manifests_path
# }

# output "kubeconfig_admin" {
#   value = nonsensitive(templatefile("./templates/kubeconfig_admin.yaml", {
#     cluster_name       = local.kubernetes.cluster_name
#     ca_pem             = module.kubernetes-common.ca.kubernetes.cert_pem
#     private_key_pem    = tls_private_key.admin.private_key_pem
#     cert_pem           = tls_locally_signed_cert.admin.cert_pem
#     apiserver_endpoint = "https://${cidrhost(local.networks.lan.prefix, local.aio_hostclass_config.vrrp_netnum)}:${local.ports.apiserver}"
#   }))
# }