resource "minio_s3_bucket" "mpd" {
  bucket        = "mpd"
  force_destroy = true
  depends_on = [
    helm_release.minio,
  ]
}

resource "minio_iam_user" "mpd" {
  name          = "mpd"
  force_destroy = true
}

resource "minio_iam_policy" "mpd" {
  name = "mpd"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          minio_s3_bucket.mpd.arn,
          "${minio_s3_bucket.mpd.arn}/*",
          minio_s3_bucket.data["music"].arn,
          "${minio_s3_bucket.data["music"].arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "mpd" {
  user_name   = minio_iam_user.mpd.id
  policy_name = minio_iam_policy.mpd.id
}

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

  minio_endpoint          = "http://${local.kubernetes_services.minio.fqdn}:${local.service_ports.minio}"
  minio_bucket            = minio_s3_bucket.mpd.id
  minio_music_bucket      = minio_s3_bucket.data["music"].id
  minio_access_key_id     = minio_iam_user.mpd.id
  minio_secret_access_key = minio_iam_user.mpd.secret
  minio_jfs_prefix        = "$(POD_NAME)"
  minio_litestream_prefix = "$POD_NAME/litestream"
}