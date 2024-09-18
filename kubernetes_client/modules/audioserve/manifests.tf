locals {
  data_path = "/var/lib/audioserve/mnt"
  ports = {
    audioserve = 3000
  }
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.audioserve)[1]
  manifests = merge(module.s3-mount.chart.manifests, {
    "templates/service.yaml" = module.service.manifest
    "templates/ingress.yaml" = module.ingress.manifest
  })
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
        port       = local.ports.audioserve
        protocol   = "TCP"
        targetPort = local.ports.audioserve
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
          port    = local.ports.audioserve
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
  replicas = 1
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
            --transcoding-max-parallel-processes 24 \
            %{~for arg in var.extra_audioserve_args~}
            ${arg} \
            %{~endfor~}
            ${local.data_path}
          EOF
        ]
        ports = [
          {
            containerPort = local.ports.audioserve
          },
        ]
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.ports.audioserve
            path   = "/"
          }
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.ports.audioserve
            path   = "/"
          }
        }
      },
    ]
  }
}