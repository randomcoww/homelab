module "mpd" {
  source  = "./modules/mpd"
  name    = "mpd"
  release = "0.1.0"
  images = {
    mpd        = local.container_images.mpd
    mympd      = local.container_images.mympd
    rclone     = local.container_images.rclone
    litestream = local.container_images.litestream
    juicefs    = local.container_images.juicefs
  }
  audio_outputs = [
    {
      name = "flac-3"
      config = {
        tags        = "yes"
        format      = "48000:24:2"
        always_on   = "yes"
        encoder     = "flac"
        compression = 3
        max_clients = 2
      }
    },
    {
      name = "lame-9"
      config = {
        tags        = "yes"
        format      = "48000:24:2"
        always_on   = "yes"
        encoder     = "lame"
        quality     = 9
        max_clients = 2
      }
    },
  ]

  jfs_minio_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  jfs_minio_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  jfs_minio_bucket            = local.minio_buckets.juicefs.name
  jfs_minio_endpoint          = "${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"

  data_minio_access_key_id     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  data_minio_secret_access_key = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  data_minio_bucket            = local.minio_buckets.music.name
  data_minio_endpoint          = "${local.kubernetes_services.minio.fqdn}:${local.service_ports.minio}"

  service_hostname          = local.kubernetes_ingress_endpoints.mpd
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations
}