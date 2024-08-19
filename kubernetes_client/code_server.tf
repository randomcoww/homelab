module "jupyter" {
  source  = "./modules/code_server"
  name    = "jupyter"
  release = "0.1.1"
  images = {
    code_server = local.container_images.jupyter
    jfs         = local.container_images.jfs
    litestream  = local.container_images.litestream
  }
  user                      = local.users.client.name
  uid                       = local.users.client.uid
  code_server_extra_configs = []
  code_server_extra_envs = [
    {
      name  = "MC_HOST_m"
      value = "http://${data.terraform_remote_state.sr.outputs.minio.access_key_id}:${data.terraform_remote_state.sr.outputs.minio.secret_access_key}@${local.kubernetes_services.minio.fqdn}:${local.service_ports.minio}"
    },
  ]
  code_server_resources = {
    limits = {
      "nvidia.com/gpu" = 1
    }
  }
  code_server_security_context = {
    capabilities = {
      add = [
        "AUDIT_WRITE",
      ]
    }
  }
  service_hostname          = local.kubernetes_ingress_endpoints.jupyter
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations

  jfs_minio_access_key_id            = data.terraform_remote_state.sr.outputs.minio.access_key_id
  jfs_minio_secret_access_key        = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  jfs_minio_bucket_endpoint          = "http://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}/${local.minio_buckets.jfs.name}"
  litestream_minio_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  litestream_minio_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  litestream_minio_bucket_endpoint   = "http://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}/${local.minio_buckets.litestream.name}"
}