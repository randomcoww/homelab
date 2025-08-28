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
  service_hostname          = local.kubernetes_ingress_endpoints.audioserve
  ingress_class_name        = local.ingress_classes.ingress_nginx
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
  service_hostname          = local.kubernetes_ingress_endpoints.webdav_pictures
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations

  minio_endpoint          = "https://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
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
  service_hostname          = local.kubernetes_ingress_endpoints.webdav_videos
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations

  minio_endpoint          = "https://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
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
  args = [
    "bash",
    "-c",
    <<EOF
    set -e

    ## Driver ##

    mkdir -p $HOME/nvidia
    targetarch=$(arch)
    driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader --id=0)
    driver_file=$HOME/nvidia/NVIDIA-Linux-$targetarch-$driver_version.run

    NVIDIA_DRIVER_BASE_URL=$${NVIDIA_DRIVER_BASE_URL:-https://us.download.nvidia.com/XFree86/$${targetarch/x86_64/Linux-x86_64}}
    curl -L --skip-existing -o "$driver_file" \
      $NVIDIA_DRIVER_BASE_URL/$driver_version/NVIDIA-Linux-$targetarch-$driver_version.run

    chmod +x "$driver_file"

    # TODO: try removing --no-install-libglvnd when https://github.com/LizardByte/Sunshine/issues/4050 is resolved
    "$driver_file" \
      --silent \
      --accept-license \
      --skip-depmod \
      --skip-module-unload \
      --no-kernel-modules \
      --no-kernel-module-source \
      --install-compat32-libs \
      --no-nouveau-check \
      --no-nvidia-modprobe \
      --no-systemd \
      --no-distro-scripts \
      --no-rpms \
      --no-backup \
      --no-check-for-alternate-installs \
      --no-libglx-indirect \
      --no-install-libglvnd

    ## User ##

    mkdir -p $HOME $XDG_RUNTIME_DIR
    chown $UID:$UID $HOME $XDG_RUNTIME_DIR

    useradd $USER -d $HOME -m -u $UID
    usermod -G wheel,video,input,render,dbus,seat $USER

    ## Udev ##

    /lib/systemd/systemd-udevd &

    ## Seatd ##

    seatd -u $USER &

    runuser -p -u $USER -- bash <<EOT
    set -e
    cd $HOME

    ## Pulseaudio ##

    pulseaudio \
      --log-level=0 \
      --daemonize=true \
      --disallow-exit=true \
      --log-target=stderr \
      --exit-idle-time=-1

    ## Sway ##

    sway &
    while ! wlr-randr >/dev/null 2>&1; do
    sleep 1
    done

    ## Sunshine ##

    sunshine --creds $SUNSHINE_USERNAME $SUNSHINE_PASSWORD
    exec sunshine \
      origin_web_ui_allowed=wan \
      port=$SUNSHINE_PORT \
      file_apps=/etc/sunshine/apps.json \
      upnp=off
    EOT
    EOF
  ]
  user               = "sunshine"
  uid                = 10000
  storage_class_name = "local-path"
  extra_configs = [
    {
      path = "/etc/sunshine/apps.json"
      content = jsonencode({
        apps = [
          {
            name       = "Desktop"
            image-path = "desktop.png"
            prep-cmd = [
              {
                do = "/usr/local/bin/sunshine-prep-cmd.sh"
              },
            ]
          }
        ],
        env = {
          PATH = "$(PATH):$(HOME)/.local/bin"
        }
      })
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
      name  = "NVIDIA_VISIBLE_DEVICES"
      value = "all"
    },
    {
      name  = "NVIDIA_DRIVER_CAPABILITIES"
      value = "all"
    },
    {
      name  = "TZ"
      value = local.timezone
    },
    {
      name  = "WAYLAND_DISPLAY"
      value = "wayland-1"
    },
  ]
  resources = {
    requests = {
      memory = "12Gi"
    }
  }
  loadbalancer_class_name = "kube-vip.io/kube-vip-class"
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
  admin_hostname            = local.kubernetes_ingress_endpoints.sunshine_admin
  ingress_class_name        = local.ingress_classes.ingress_nginx
  nginx_ingress_annotations = local.nginx_ingress_annotations
}