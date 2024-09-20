## audioserve

resource "minio_iam_user" "audioserve" {
  name          = "audioserve"
  force_destroy = true
}

resource "minio_iam_policy" "audioserve" {
  name = "audioserve"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          minio_s3_bucket.data["music"].arn,
          "${minio_s3_bucket.data["music"].arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "audioserve" {
  user_name   = minio_iam_user.audioserve.id
  policy_name = minio_iam_policy.audioserve.id
}

module "audioserve" {
  name      = "audioserve"
  namespace = "default"
  source    = "./modules/audioserve"
  release   = "0.1.0"
  images = {
    audioserve = local.container_images.audioserve
    mountpoint = local.container_images.mountpoint
  }
  extra_audioserve_args = [
    "--read-playlist",
  ]
  service_hostname          = local.kubernetes_ingress_endpoints.audioserve
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations

  s3_endpoint          = "http://${local.services.minio.ip}:${local.service_ports.minio}"
  s3_bucket            = minio_s3_bucket.data["music"].id
  s3_access_key_id     = minio_iam_user.audioserve.id
  s3_secret_access_key = minio_iam_user.audioserve.secret
  s3_mount_extra_args = [
    "--cache /tmp",
    "--read-only",
  ]
}

## webdav

resource "minio_iam_user" "webdav-pictures" {
  name          = "webdav-pictures"
  force_destroy = true
}

resource "minio_iam_policy" "webdav-pictures" {
  name = "webdav-pictures"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          minio_s3_bucket.data["pictures"].arn,
          "${minio_s3_bucket.data["pictures"].arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "webdav-pictures" {
  user_name   = minio_iam_user.webdav-pictures.id
  policy_name = minio_iam_policy.webdav-pictures.id
}

module "webdav-pictures" {
  source  = "./modules/webdav"
  name    = "webdav-pictures"
  release = "0.1.0"
  images = {
    caddy_webdav = local.container_images.caddy_webdav
    mountpoint   = local.container_images.mountpoint
  }
  service_hostname          = local.kubernetes_ingress_endpoints.webdav_pictures
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations

  s3_endpoint          = "http://${local.services.minio.ip}:${local.service_ports.minio}"
  s3_bucket            = minio_s3_bucket.data["pictures"].id
  s3_access_key_id     = minio_iam_user.webdav-pictures.id
  s3_secret_access_key = minio_iam_user.webdav-pictures.secret
}

resource "minio_iam_user" "webdav-videos" {
  name          = "webdav-videos"
  force_destroy = true
}

resource "minio_iam_policy" "webdav-videos" {
  name = "webdav-videos"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = [
          minio_s3_bucket.data["videos"].arn,
          "${minio_s3_bucket.data["videos"].arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "webdav-videos" {
  user_name   = minio_iam_user.webdav-videos.id
  policy_name = minio_iam_policy.webdav-videos.id
}

module "webdav-videos" {
  source  = "./modules/webdav"
  name    = "webdav-videos"
  release = "0.1.0"
  images = {
    caddy_webdav = local.container_images.caddy_webdav
    mountpoint   = local.container_images.mountpoint
  }
  service_hostname          = local.kubernetes_ingress_endpoints.webdav_videos
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations

  s3_endpoint          = "http://${local.services.minio.ip}:${local.service_ports.minio}"
  s3_bucket            = minio_s3_bucket.data["videos"].id
  s3_access_key_id     = minio_iam_user.webdav-videos.id
  s3_secret_access_key = minio_iam_user.webdav-videos.secret
}

## sunshine

module "sunshine" {
  source  = "./modules/sunshine"
  name    = "sunshine"
  release = "0.1.1"
  images = {
    sunshine   = local.container_images.sunshine
    mountpoint = local.container_images.mountpoint
  }
  sunshine_extra_envs = [
    {
      name  = "XDG_RUNTIME_DIR"
      value = "/run/user/${local.users.client.uid}"
    },
  ]
  sunshine_extra_volumes = [
    {
      name = "run-user"
      hostPath = {
        path = "/run/user/${local.users.client.uid}"
        type = "Directory"
      }
    },
  ]
  sunshine_extra_args = [
    {
      name  = "encoder"
      value = "nvenc"
    },
    {
      name  = "key_rightalt_to_key_win"
      value = "enabled"
    },
    {
      name  = "output_name"
      value = "1"
    },
  ]
  sunshine_resources = {
    # limits = {
    #   "nvidia.com/gpu.shared" = 1
    # }
  }
  sunshine_extra_volume_mounts = [
    {
      name      = "run-user"
      mountPath = "/run/user/${local.users.client.uid}"
    },
  ]
  sunshine_security_context = {
    privileged = true
    runAsUser  = local.users.client.uid
    fsGroup    = local.users.client.uid
  }
  storage_class_name = "local-path"
  affinity = {
    nodeAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = {
        nodeSelectorTerms = [
          {
            matchExpressions = [
              {
                key      = "kubernetes.io/hostname"
                operator = "In"
                values = [
                  "de-1.local",
                ]
              },
            ]
          },
        ]
      }
    }
  }
  service_hostname          = local.kubernetes_ingress_endpoints.sunshine
  service_ip                = local.services.sunshine.ip
  admin_hostname            = local.kubernetes_ingress_endpoints.sunshine_admin
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations
}