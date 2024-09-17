module "mpd" {
  source  = "./modules/mpd"
  name    = "mpd"
  release = "0.1.0"
  images = {
    mpd        = local.container_images.mpd
    mympd      = local.container_images.mympd
    rclone     = local.container_images.rclone
    jfs        = local.container_images.jfs
    litestream = local.container_images.litestream
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

  jfs_minio_endpoint                 = "http://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
  jfs_minio_bucket                   = local.minio_buckets.fs.name
  jfs_minio_access_key_id            = data.terraform_remote_state.sr.outputs.minio.access_key_id
  jfs_minio_secret_access_key        = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  litestream_minio_endpoint          = "http://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
  litestream_minio_bucket            = local.minio_buckets.litestream.name
  litestream_minio_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  litestream_minio_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
}