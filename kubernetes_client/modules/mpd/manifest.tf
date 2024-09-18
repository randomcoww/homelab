locals {
  ports = {
    mpd    = 8000
    mympd  = 7982
    rclone = 7981
  }
  mpd_cache_path  = "/var/lib/mpd/mnt"
  mpd_socket_path = "/run/mpd/socket"
  mpd_config_path = "/etc/mpd.conf"
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.mpd)[1]
  manifests = merge(module.jfs.chart.manifests, {
    "templates/service.yaml" = module.service.manifest
    "templates/secret.yaml"  = module.secret.manifest
    "templates/ingress.yaml" = module.ingress.manifest
  })
}

module "secret" {
  source  = "../secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    basename(local.mpd_config_path) = <<-EOF
    bind_to_address "${local.mpd_socket_path}"
    music_directory "http://127.0.0.1:${local.ports.rclone}"
    playlist_directory "${local.mpd_cache_path}/playlists"
    state_file "${local.mpd_cache_path}/state"
    database {
      plugin "simple"
      path "${local.mpd_cache_path}/db"
      cache_directory "${local.mpd_cache_path}/cache"
    }
    input_cache {
      size "1 GB"
    }
    %{~for k, v in var.extra_configs~}
    ${k} "${v}"
    %{~endfor~}

    audio_output {
      type "httpd"
      name "httpd"
      port "${local.ports.mpd}"
      bind_to_address "127.0.0.1"
      tags "yes"
      format "48000:24:2"
      always_on "yes"
      max_clients "0"
      # encoder "lame"
      # quality "9"
      encoder "flac"
      compression "3"
    }
    EOF
    RCLONE_S3_ACCESS_KEY_ID         = var.minio_access_key_id
    RCLONE_S3_SECRET_ACCESS_KEY     = var.minio_secret_access_key
  }
}

module "service" {
  source  = "../service"
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = "mympd"
        port       = local.ports.mympd
        protocol   = "TCP"
        targetPort = local.ports.mympd
      },
    ]
  }
}

module "ingress" {
  source             = "../ingress"
  name               = var.name
  app                = var.name
  release            = var.release
  ingress_class_name = var.ingress_class_name
  annotations        = var.nginx_ingress_annotations
  rules = [
    {
      host = var.service_hostname
      paths = [
        {
          service = var.name
          port    = local.ports.mympd
          path    = "/"
        },
      ]
    },
  ]
}

module "jfs" {
  source = "../statefulset_jfs"
  ## jfs settings
  images = {
    litestream = var.images.litestream
    jfs        = var.images.jfs
  }
  jfs_mount_path          = local.mpd_cache_path
  minio_endpoint          = var.minio_endpoint
  minio_bucket            = var.minio_bucket
  minio_jfs_prefix        = var.minio_jfs_prefix
  minio_litestream_prefix = var.minio_litestream_prefix
  minio_access_key_id     = var.minio_access_key_id
  minio_secret_access_key = var.minio_secret_access_key
  ##
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  template_spec = {
    initContainers = [
      {
        name          = "${var.name}-rclone"
        image         = var.images.rclone
        restartPolicy = "Always"
        args = [
          "serve",
          "webdav",
          "--addr=127.0.0.1:${local.ports.rclone}",
          ":s3:${var.minio_music_bucket}",
          "--s3-provider=Minio",
          "--s3-endpoint=${var.minio_endpoint}",
          "--no-modtime",
          "--read-only",
        ]
        env = [
          {
            name = "RCLONE_S3_ACCESS_KEY_ID"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = "RCLONE_S3_ACCESS_KEY_ID"
              }
            }
          },
          {
            name = "RCLONE_S3_SECRET_ACCESS_KEY"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = "RCLONE_S3_SECRET_ACCESS_KEY"
              }
            }
          },
        ]
      },
      {
        name          = var.name
        image         = var.images.mpd
        restartPolicy = "Always"
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          mountpoint ${local.mpd_cache_path}
          mkdir -p ${local.mpd_cache_path}/playlists
          exec mpd \
            --no-daemon \
            --stdout \
            ${local.mpd_config_path}
          EOF
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.mpd_config_path
            subPath   = basename(local.mpd_config_path)
          },
          {
            name      = "socket"
            mountPath = dirname(local.mpd_socket_path)
          },
        ]
      },
    ]
    containers = [
      {
        name  = "${var.name}-mympd"
        image = var.images.mympd
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          mountpoint ${local.mpd_cache_path}
          mkdir -p ${local.mpd_cache_path}/mympd
          exec mympd \
            --workdir ${local.mpd_cache_path}/mympd
          EOF
        ]
        env = [
          {
            name  = "MPD_HOST"
            value = local.mpd_socket_path
          },
          {
            name  = "MYMPD_SSL"
            value = "false"
          },
          {
            name  = "MYMPD_HTTP_HOST"
            value = "0.0.0.0"
          },
          {
            name  = "MYMPD_HTTP_PORT"
            value = tostring(local.ports.mympd)
          },
          {
            name  = "MYMPD_ALBUM_MODE"
            value = "simple"
          },
          {
            name  = "MYMPD_SAVE_CACHES"
            value = "false"
          },
          {
            name  = "MYMPD_STICKERS"
            value = "false"
          },
        ]
        volumeMounts = [
          {
            name      = "socket"
            mountPath = dirname(local.mpd_socket_path)
          },
        ]
        ports = [
          {
            containerPort = local.ports.mympd
          },
        ]
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.ports.mympd
            path   = "/serverinfo"
          }
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.ports.mympd
            path   = "/serverinfo"
          }
        }
      },
    ]
    volumes = [
      {
        name = "config"
        secret = {
          secretName  = module.secret.name
          defaultMode = 493
        }
      },
      {
        name = "socket"
        emptyDir = {
          medium = "Memory"
        }
      },
    ]
  }
}