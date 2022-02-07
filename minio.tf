# module "minio-common" {
#   source = "./modules/minio_common"
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

# # minio credentials
# output "minio_credentials" {
#   value = {
#     for host_key, credentials in module.ignition-minio.credentials :
#     host_key => {
#       access_key_id = credentials.access_key_id
#       secret_access_key = credentials.secret_access_key
#     }
#   }
# }