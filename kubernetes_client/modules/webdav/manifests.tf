locals {
  ports = {
    webdav = 8080
  }
  data_path         = "/var/lib/caddy/mnt"
  caddy_config_path = "/etc/caddy/Caddyfile"
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.caddy_webdav)[1]
  manifests = merge(module.s3-mount.chart.manifests, {
    "templates/service.yaml"   = module.service.manifest
    "templates/configmap.yaml" = module.configmap.manifest
    "templates/ingress.yaml"   = module.ingress.manifest
  })
}

module "configmap" {
  source  = "../configmap"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    basename(local.caddy_config_path) = <<-EOF
    {
      order webdav before file_server
    }
    :${local.ports.webdav} {
      root * ${local.data_path}
      webdav
    }
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
    ports = [
      {
        name       = var.name
        port       = local.ports.webdav
        protocol   = "TCP"
        targetPort = local.ports.webdav
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
          port    = local.ports.webdav
          path    = "/"
        },
      ]
    },
  ]
}

module "s3-mount" {
  source = "../statefulset_s3"
  ## s3 config
  s3_endpoint          = var.s3_endpoint
  s3_bucket            = var.s3_bucket
  s3_prefix            = ""
  s3_access_key_id     = var.s3_access_key_id
  s3_secret_access_key = var.s3_secret_access_key
  s3_mount_path        = local.data_path
  s3_mount_extra_args  = var.s3_mount_extra_args
  images = {
    mountpoint = var.images.mountpoint
  }
  ##
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = var.replicas
  annotations = {
    "checksum/configmap" = sha256(module.configmap.manifest)
  }
  template_spec = {
    containers = [
      {
        name  = var.name
        image = var.images.caddy_webdav
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          until mountpoint ${local.data_path}; do
          sleep 1
          done

          exec caddy run \
            --config=${local.caddy_config_path}
          EOF
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.caddy_config_path
            subPath   = basename(local.caddy_config_path)
          },
        ]
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.ports.webdav
            path   = "/"
          }
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.ports.webdav
            path   = "/"
          }
        }
      },
    ]
    volumes = [
      {
        name = "config"
        configMap = {
          name = module.configmap.name
        }
      },
    ]
  }
}