## audioserve

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

  minio_endpoint      = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket        = "data-music"
  minio_access_secret = local.minio_users.audioserve.secret
  minio_mount_extra_args = [
    "--read-only",
  ]
}

## webdav

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

  minio_endpoint      = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket        = "data-pictures"
  minio_access_secret = local.minio_users.rclone-pictures.secret
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

  minio_endpoint      = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
  minio_bucket        = "data-videos"
  minio_access_secret = local.minio_users.rclone-videos.secret
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