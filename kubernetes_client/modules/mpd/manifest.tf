locals {
  ports = {
    mpd    = 8000
    mympd  = 7982
    rclone = 7981
  }
  mpd_cache_path    = "/var/lib/mpd/mnt"
  mpd_socket_path   = "/run/mpd/socket"
  mpd_config_path   = "/etc/mpd.conf"
  jfs_metadata_path = "/var/lib/jfs/${var.name}.db"
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.mpd)[1]
  manifests = {
    "templates/service.yaml"     = module.service.manifest
    "templates/secret.yaml"      = module.secret.manifest
    "templates/ingress.yaml"     = module.ingress.manifest
    "templates/statefulset.yaml" = module.statefulset-jfs.statefulset
    "templates/secret-jfs.yaml"  = module.statefulset-jfs.secret
  }
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
      encoder "lame"
      quality "9"
      # encoder "flac"
      # compression "3"
    }
    EOF
    RCLONE_S3_ACCESS_KEY_ID         = var.data_minio_access_key_id
    RCLONE_S3_SECRET_ACCESS_KEY     = var.data_minio_secret_access_key
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

module "statefulset-jfs" {
  source = "../statefulset_jfs"
  ## jfs settings
  jfs_redis_endpoint          = var.jfs_redis_endpoint
  jfs_redis_db_id             = var.jfs_redis_db_id
  jfs_redis_ca                = var.jfs_redis_ca
  jfs_image                   = var.images.juicefs
  jfs_mount_path              = local.mpd_cache_path
  jfs_minio_resource          = "http://${var.jfs_minio_endpoint}/${var.jfs_minio_resource}"
  jfs_minio_access_key_id     = var.jfs_minio_access_key_id
  jfs_minio_secret_access_key = var.jfs_minio_secret_access_key
  ##

  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  spec = {
    containers = [
      {
        name  = "${var.name}-rclone"
        image = var.images.rclone
        args = [
          "serve",
          "webdav",
          "--addr=127.0.0.1:${local.ports.rclone}",
          ":s3:${var.data_minio_bucket}",
          "--s3-provider=Minio",
          "--s3-endpoint=http://${var.data_minio_endpoint}",
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
        name  = var.name
        image = var.images.mpd
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