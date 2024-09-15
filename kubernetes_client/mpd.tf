module "mpd" {
  source  = "./modules/mpd"
  name    = "mpd"
  release = "0.1.0"
  images = {
    mpd        = local.container_images.mpd
    mympd      = local.container_images.mympd
    rclone     = local.container_images.rclone
    mountpoint = local.container_images.mountpoint
  }
  extra_configs = {
    metadata_to_use = "AlbumArtist,Artist,Album,Title,Track,Disc,Genre,Name,Date"
  }
  service_hostname          = local.kubernetes_ingress_endpoints.mpd
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations

  data_minio_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  data_minio_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  data_minio_bucket            = local.minio_buckets.music.name
  data_minio_endpoint          = "${local.kubernetes_services.minio.fqdn}:${local.service_ports.minio}"

  s3_mount_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  s3_mount_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  s3_mount_endpoint          = "http://${local.services.minio.ip}:${local.service_ports.minio}"
  s3_mount_bucket            = local.minio_buckets.jfs.name
}