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
    "templates/secret.yaml"     = module.secret.manifest
    "templates/service.yaml"    = module.service.manifest
    "templates/ingress.yaml"    = module.ingress.manifest
    "templates/deployment.yaml" = module.deployment.manifest
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
  annotations        = var.nginx_ingress_annotations
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

module "deployment" {
  source   = "../deployment"
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
    containers = [
      {
        name  = var.name
        image = var.images.mpd
        volumeMounts = [
          {
            name      = "mpd-config"
            mountPath = "/etc/mpd.conf"
            subPath   = "mpd.conf"
          },
          {
            name      = "mpd-socket"
            mountPath = local.mpd_socket_path
          },
        ]
        env = [
          {
            name  = "CACHE_MOUNT_PATH"
            value = local.mpd_cache_path
          },
          {
            name  = "WEBDAV_PORT"
            value = tostring(var.ports.rclone)
          },
          {
            name  = "MPD_CONF_PATH"
            value = "/etc/mpd.conf"
          },
          {
            name  = "S3_CACHE_RESOURCE"
            value = var.s3_cache_resource
          },
          {
            name  = "S3_MUSIC_RESOURCE"
            value = var.s3_music_resource
          },
          {
            name  = "S3_PROVIDER"
            value = "Minio"
          },
          {
            name  = "S3_ENDPOINT"
            value = var.s3_endpoint
          },
          {
            name  = "VFS_CACHE_MODE"
            value = "writes"
          },
        ]
        ports = [
          for o in local.audio_outputs :
          {
            containerPort = o.port
          }
        ]
        securityContext = {
          capabilities = {
            add = [
              "SYS_ADMIN",
            ]
          }
        }
        resources = var.resources
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
          },
        ]
        ports = [
          {
            containerPort = var.ports.mympd
          },
        ]
        volumeMounts = [
          {
            name      = "mpd-socket"
            mountPath = local.mpd_socket_path
          },
        ]
      },
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
}