locals {
  config_file     = "/etc/audioserve/config.yaml"
  data_path       = "/var/lib/audioserve/music"
  audioserve_port = 3000
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.release
  manifests = merge(module.mountpoint.chart.manifests, {
    "templates/service.yaml"   = module.service.manifest
    "templates/ingress.yaml"   = module.ingress.manifest
    "templates/configmap.yaml" = module.configmap.manifest
  })
}

module "configmap" {
  source  = "../../../modules/configmap"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    "config.yaml" = yamlencode(var.transcoding_config)
  }
}

module "service" {
  source  = "../../../modules/service"
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = var.name
        port       = local.audioserve_port
        protocol   = "TCP"
        targetPort = local.audioserve_port
      },
    ]
    sessionAffinity = "ClientIP"
    sessionAffinityConfig = {
      clientIP = {
        timeoutSeconds = 10800
      }
    }
  }
}

module "ingress" {
  source             = "../../../modules/ingress"
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
          port    = local.audioserve_port
          path    = "/"
        },
      ]
    },
  ]
}

module "mountpoint" {
  source = "../statefulset_mountpoint"
  ## s3 config
  s3_endpoint   = var.minio_endpoint
  s3_bucket     = var.minio_bucket
  s3_prefix     = ""
  s3_mount_path = local.data_path
  s3_mount_extra_args = concat(var.minio_mount_extra_args, [
    "--cache ${dirname(local.data_path)}",
  ])
  s3_access_secret = var.minio_access_secret
  images = {
    mountpoint = var.images.mountpoint
  }
  ##
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  annotations = {
    "checksum/configmap" = sha256(module.configmap.manifest)
  }
  affinity = var.affinity
  replicas = var.replicas
  template_spec = {
    containers = [
      {
        name  = var.name
        image = var.images.audioserve
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          until mountpoint ${local.data_path}; do
          sleep 1
          done

          exec ./audioserve \
            --behind-proxy \
            --no-authentication \
            --disable-folder-download \
            --config ${local.config_file} \
            %{~for arg in var.extra_audioserve_args~}
            ${arg} \
            %{~endfor~}
            ${local.data_path}
          EOF
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.config_file
            subPath   = "config.yaml"
          },
        ]
        ports = [
          {
            containerPort = local.audioserve_port
          },
        ]
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.audioserve_port
            path   = "/"
          }
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.audioserve_port
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