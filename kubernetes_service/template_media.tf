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
  nginx_ingress_annotations = local.nginx_ingress_annotations

  s3_endpoint          = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
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
}

## Sunshine desktop

module "sunshine-desktop" {
  source  = "./modules/sunshine_desktop"
  name    = "sunshine-desktop"
  release = "0.1.1"
  images = {
    sunshine_desktop = local.container_images.sunshine_desktop
  }
  user      = local.users.client.name
  uid       = local.users.client.uid
  home_path = local.users.client.home_dir
  extra_configs = [
    {
      path    = "/etc/tmux.conf"
      content = <<-EOF
      set -g history-limit 10000
      set -g mouse on
      set-option -s set-clipboard off
      bind-key -T copy-mode MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -in -sel clip"
      EOF
    },
    {
      path    = "/etc/xdg/xfce4/terminal/terminalrc"
      content = <<-EOF
      [Configuration]
      MiscTabCloseMiddleClick=FALSE
      MiscShowUnsafePasteDialog=FALSE
      MiscConfirmClose=FALSE
      EOF
    },
    {
      path    = "/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"
      content = <<-EOF
      <?xml version="1.0" encoding="UTF-8"?>

      <channel name="xfce4-desktop" version="1.0">
        <property name="desktop-icons" type="empty">
          <property name="style" type="int" value="0"/>
        </property>
      </channel>
      EOF
    },
    {
      path    = "/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
      content = <<-EOF
      <?xml version="1.0" encoding="UTF-8"?>

      <channel name="xfce4-panel" version="1.0">
        <property name="configver" type="int" value="2"/>
        <property name="panels" type="array">
          <value type="int" value="1"/>
          <property name="dark-mode" type="bool" value="true"/>
          <property name="panel-1" type="empty">
            <property name="position" type="string" value="p=6;x=0;y=0"/>
            <property name="length" type="double" value="100"/>
            <property name="position-locked" type="bool" value="true"/>
            <property name="icon-size" type="uint" value="0"/>
            <property name="size" type="uint" value="30"/>
            <property name="plugin-ids" type="array">
              <value type="int" value="1"/>
              <value type="int" value="2"/>
              <value type="int" value="3"/>
            </property>
            <property name="mode" type="uint" value="1"/>
            <property name="enable-struts" type="bool" value="true"/>
          </property>
        </property>
        <property name="plugins" type="empty">
          <property name="plugin-1" type="string" value="tasklist">
            <property name="grouping" type="uint" value="1"/>
          </property>
          <property name="plugin-2" type="string" value="separator">
            <property name="expand" type="bool" value="true"/>
            <property name="style" type="uint" value="0"/>
          </property>
          <property name="plugin-3" type="string" value="pager"/>
        </property>
      </channel>
      EOF
    },
    {
      path    = "/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml"
      content = <<-EOF
      <?xml version="1.0" encoding="UTF-8"?>

      <channel name="xsettings" version="1.0">
        <property name="Net" type="empty">
          <property name="IconThemeName" type="string" value="gnome"/>
        </property>
      </channel>
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
      name = "NVIDIA_DRIVER_BASE_URL"
      # value = "https://us.download.nvidia.com/tesla"
      value = "https://us.download.nvidia.com/XFree86/Linux-x86_64"
    },
    {
      name  = "TZ"
      value = local.timezone
    },
    {
      name = "SUNSHINE_EXTRA_ARGS"
      value = join(" ", [
        "key_rightalt_to_key_win=enabled",
      ])
    },
  ]
  resources = {
    requests = {
      memory = "12Gi"
    }
    limits = {
      "nvidia.com/gpu" = 1
    }
  }
  security_context = {
    privileged = true
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
  nginx_ingress_annotations = local.nginx_ingress_auth_annotations
}
