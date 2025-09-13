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
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload",
        ]
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
  replicas  = 2
  images = {
    audioserve = local.container_images.audioserve
    mountpoint = local.container_images.mountpoint
  }
  extra_audioserve_args = [
    "--read-playlist",
  ]
  transcoding_config = {
    transcoding = {
      alt_configs = {
        "iPhone|IPad|Mac OS" = {
          low = {
            "aac-in-adts" = {
              bitrate = 32
              sr      = "24kHz"
              mono    = true
            }
          }
          medium = {
            "aac-in-adts" = {
              bitrate = 48
              mono    = false
            }
          }
          high = {
            "aac-in-adts" = {
              bitrate = 64
              mono    = false
            }
          }
        }
      }
    }
  }
  service_hostname          = local.ingress_endpoints.audioserve
  ingress_class_name        = local.kubernetes.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations

  s3_endpoint          = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  s3_bucket            = minio_s3_bucket.data["music"].id
  s3_access_key_id     = minio_iam_user.audioserve.id
  s3_secret_access_key = minio_iam_user.audioserve.secret
  s3_mount_extra_args = [
    "--cache /tmp",
    "--read-only",
  ]

  depends_on = [
    minio_iam_user.audioserve,
    minio_iam_policy.audioserve,
    minio_iam_user_policy_attachment.audioserve,
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
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
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
  source   = "./modules/webdav"
  name     = "webdav-pictures"
  release  = "0.1.0"
  replicas = 2
  images = {
    rclone = local.container_images.rclone
  }
  service_hostname          = local.ingress_endpoints.webdav_pictures
  ingress_class_name        = local.kubernetes.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations

  minio_endpoint          = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket            = minio_s3_bucket.data["pictures"].id
  minio_access_key_id     = minio_iam_user.webdav-pictures.id
  minio_secret_access_key = minio_iam_user.webdav-pictures.secret
  minio_ca_cert           = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem

  depends_on = [
    minio_iam_user.webdav-pictures,
    minio_iam_policy.webdav-pictures,
    minio_iam_user_policy_attachment.webdav-pictures,
  ]
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
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
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
  source   = "./modules/webdav"
  name     = "webdav-videos"
  release  = "0.1.0"
  replicas = 2
  images = {
    rclone = local.container_images.rclone
  }
  service_hostname          = local.ingress_endpoints.webdav_videos
  ingress_class_name        = local.kubernetes.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations

  minio_endpoint          = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket            = minio_s3_bucket.data["videos"].id
  minio_access_key_id     = minio_iam_user.webdav-videos.id
  minio_secret_access_key = minio_iam_user.webdav-videos.secret
  minio_ca_cert           = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem

  depends_on = [
    minio_iam_user.webdav-videos,
    minio_iam_policy.webdav-videos,
    minio_iam_user_policy_attachment.webdav-videos,
  ]
}

## Sunshine desktop

module "sunshine-desktop" {
  source  = "./modules/sunshine_desktop"
  name    = "sunshine-desktop"
  release = "0.1.1"
  images = {
    sunshine_desktop = local.container_images.sunshine_desktop
  }
  user               = "sunshine"
  uid                = 10000
  storage_class_name = "local-path"
  extra_configs = [
    {
      path    = "/etc/xdg/foot/foot.ini"
      content = <<-EOF
      font=monospace:size=14
      EOF
    },
    {
      path    = "/etc/tmux.conf"
      content = <<-EOF
      set -g history-limit 10000
      set -g mouse on
      set-option -s set-clipboard off
      bind-key -T copy-mode MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -in -sel clip"
      EOF
    },
  ]
  extra_envs = [
    {
      name  = "NVIDIA_DRIVER_CAPABILITIES"
      value = "all"
    },
    {
      name  = "__NV_PRIME_RENDER_OFFLOAD"
      value = 1
    },
    {
      name  = "__GLX_VENDOR_LIBRARY_NAME"
      value = "nvidia"
    },
    {
      name  = "TZ"
      value = local.timezone
    },
  ]
  resources = {
    requests = {
      memory = "12Gi"
    }
    limits = {
      "nvidia.com/gpu" = 1
      "amd.com/gpu"    = 1
    }
  }
  # TODO: Revisit - currently privileged to make libinput work
  security_context = {
    privileged = true
  }
  loadbalancer_class_name   = "kube-vip.io/kube-vip-class"
  admin_hostname            = local.ingress_endpoints.sunshine_admin
  ingress_class_name        = local.kubernetes.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations
}