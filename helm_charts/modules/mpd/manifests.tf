locals {
  audio_outputs = [
    for i, o in var.audio_outputs :
    merge(o, {
      port = var.ports.audio_output_base + i
    })
  ]
  mpd_cache_path  = "/var/lib/mpd"
  mpd_socket_path = "/run/mpd"
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.mpd)[1]
  manifests = {
    "templates/secret.yaml"      = module.secret.manifest
    "templates/service.yaml"     = module.service.manifest
    "templates/ingress.yaml"     = module.ingress.manifest
    "templates/statefulset.yaml" = module.statefulset.manifest
  }
}

module "secret" {
  source  = "../secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    "mpd.conf" = templatefile("${path.module}/templates/mpd.conf", {
      mpd_cache_path  = local.mpd_cache_path
      mpd_socket_path = local.mpd_socket_path
      extra_configs   = var.extra_configs
      audio_outputs   = local.audio_outputs
      rclone_port     = var.ports.rclone
    })
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
        port       = var.ports.mympd
        protocol   = "TCP"
        targetPort = var.ports.mympd
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
  cert_issuer        = var.ingress_cert_issuer
  auth_url           = var.ingress_auth_url
  auth_signin        = var.ingress_auth_signin
  rules = [
    {
      host = var.service_hostname
      paths = concat([
        {
          service = var.name
          port    = var.ports.mympd
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

module "statefulset" {
  source   = "../statefulset"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = 1
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  spec = {
    dnsPolicy = "ClusterFirstWithHostNet"
    initContainers = [
      {
        name  = "${var.name}-init"
        image = var.images.mpd
        command = [
          "sh",
          "-c",
          <<EOF
mkdir -p ${local.mpd_cache_path}/playlists && \
touch \
  ${local.mpd_cache_path}/tag_cache \
  ${local.mpd_cache_path}/state \
  ${local.mpd_cache_path}/sticker.sql
EOF
        ]
        volumeMounts = [
          {
            name      = "mpd-cache"
            mountPath = local.mpd_cache_path
          },
        ]
      }
    ]
    containers = [
      {
        name  = var.name
        image = var.images.mpd
        args = [
          "--stdout",
          "/etc/mpd.conf",
        ]
        volumeMounts = [
          {
            name      = "mpd-config"
            mountPath = "/etc/mpd.conf"
            subPath   = "mpd.conf"
          },
          {
            name      = "mpd-cache"
            mountPath = local.mpd_cache_path
          },
          {
            name      = "mpd-socket"
            mountPath = local.mpd_socket_path
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
            value = "${local.mpd_socket_path}/socket"
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
            value = tostring(var.ports.mympd)
          }
        ]
        ports = [
          {
            containerPort = var.ports.mympd
          }
        ]
        volumeMounts = [
          {
            name      = "mpd-socket"
            mountPath = local.mpd_socket_path
          }
        ]
      },
      {
        name  = "${var.name}-rclone"
        image = var.images.rclone
        args = [
          "serve",
          "webdav",
          "--addr=127.0.0.1:${var.ports.rclone}",
          ":s3:${var.s3_resource}",
          "--s3-provider=Minio",
          "--s3-endpoint=${var.s3_endpoint}",
          "--no-modtime",
          "--read-only",
        ]
      }
    ]
    volumes = [
      {
        name = "mpd-config"
        secret = {
          secretName = var.name
        }
      },
      {
        name = "mpd-socket"
        emptyDir = {
          medium = "Memory"
        }
      },
    ]
  }
  volume_claim_templates = [
    {
      metadata = {
        name = "mpd-cache"
        spec = {
          resources = {
            requests = {
              storage = var.volume_claim_size
            }
          }
          storageClassName = var.storage_class
        }
      }
    }
  ]
}