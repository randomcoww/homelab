locals {
  ports = {
    mpd               = 8000
    rclone            = 8001
    mympd             = 8002
    audio_output_base = 8080
  }
  audio_outputs = [
    for i, o in var.audio_outputs :
    merge(o, {
      port = local.ports.audio_output_base + i
    })
  ]
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
    "templates/service.yaml"           = module.service.manifest
    "templates/secret.yaml"            = module.secret.manifest
    "templates/ingress.yaml"           = module.ingress.manifest
    "templates/statefulset.yaml"       = module.statefulset-jfs.statefulset
    "templates/secret-litestream.yaml" = module.statefulset-jfs.secret
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
    sticker_file "${local.mpd_cache_path}/sticker.sql"
    playlist_directory "${local.mpd_cache_path}"
    state_file "${local.mpd_cache_path}/state"
    database {
      plugin "simple"
      path "${local.mpd_cache_path}/db"
    }
    input_cache {
      size "1 GB"
    }
    %{~for k, v in var.extra_configs~}
    ${k} "${v}"
    %{~endfor~}
    %{~for i, o in local.audio_outputs~}

    audio_output {
      type "httpd"
      name "${o.name}"
      port "${o.port}"
      bind_to_address "0.0.0.0"
      %{~for k, v in o.config~}
      ${k} "${v}"
      %{~endfor~}
    }
    %{~endfor~}
    EOF
  }
}

module "service" {
  source  = "../service"
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    type = "ClusterIP"
    ports = concat([
      {
        name       = "mympd"
        port       = local.ports.mympd
        protocol   = "TCP"
        targetPort = local.ports.mympd
      },
      ], [
      for o in local.audio_outputs :
      {
        name       = o.name
        port       = o.port
        protocol   = "TCP"
        targetPort = o.port
      }
    ])
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
      paths = concat([
        {
          service = var.name
          port    = local.ports.mympd
          path    = "/"
        }
        ], [
        for o in local.audio_outputs :
        {
          service = var.name
          port    = o.port
          path    = "/${o.name}"
        }
      ])
    },
  ]
}

module "statefulset-jfs" {
  source = "../statefulset_jfs"
  ## litestream settings
  litestream_image = var.images.litestream
  litestream_config = {
    dbs = [
      {
        path = local.jfs_metadata_path
        replicas = [
          {
            type                     = "s3"
            bucket                   = var.jfs_minio_bucket
            path                     = basename(local.jfs_metadata_path)
            endpoint                 = "http://${var.jfs_minio_endpoint}"
            access-key-id            = var.jfs_minio_access_key_id
            secret-access-key        = var.jfs_minio_secret_access_key
            retention                = "2m"
            retention-check-interval = "2m"
            sync-interval            = "500ms"
            snapshot-interval        = "1h"
          },
        ]
      },
    ]
  }
  sqlite_path = local.jfs_metadata_path

  ## jfs settings
  jfs_image                   = var.images.juicefs
  jfs_mount_path              = local.mpd_cache_path
  jfs_minio_resource          = "http://${var.jfs_minio_endpoint}/${var.jfs_minio_bucket}"
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
            name  = "RCLONE_S3_ACCESS_KEY_ID"
            value = var.data_minio_access_key_id
          },
          {
            name  = "RCLONE_S3_SECRET_ACCESS_KEY"
            value = var.data_minio_secret_access_key
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
        ports = [
          for o in local.audio_outputs :
          {
            containerPort = o.port
          }
        ]
      },
      {
        name  = "${var.name}-mympd"
        image = var.images.mympd
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