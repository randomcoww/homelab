module "webdav-pictures" {
  source  = "./modules/webdav"
  name    = "webdav-pictures"
  release = "0.1.0"
  images = {
    rclone = local.container_images.rclone
  }

  data_minio_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  data_minio_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  data_minio_bucket            = local.minio_buckets.pictures.name
  data_minio_endpoint          = "${local.kubernetes_services.minio.fqdn}:${local.service_ports.minio}"

  service_hostname          = local.kubernetes_ingress_endpoints.webdav_pictures
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations
}