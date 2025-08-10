locals {
  data_path     = "/var/lib/node_red/mnt"
  node_red_port = 1880
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.node_red)[1]
  manifests = merge(module.s3fs.chart.manifests, {
    "templates/service.yaml" = module.service.manifest
    "templates/ingress.yaml" = module.ingress.manifest
    "templates/secret.yaml"  = module.secret.manifest
  })
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    for key, value in var.extra_envs :
    key => tostring(value)
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
        port       = local.node_red_port
        protocol   = "TCP"
        targetPort = local.node_red_port
      },
    ]
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
          service = module.service.name
          port    = local.node_red_port
          path    = "/"
        },
      ]
    },
  ]
}

module "s3fs" {
  source = "../statefulset_s3fs"
  ## s3 config
  s3_endpoint          = var.s3_endpoint
  s3_bucket            = var.s3_bucket
  s3_prefix            = ""
  s3_access_key_id     = var.s3_access_key_id
  s3_secret_access_key = var.s3_secret_access_key
  s3_mount_path        = local.data_path
  s3_mount_extra_args  = var.s3_mount_extra_args
  images = {
    s3fs = var.images.s3fs
  }
  ##
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  replicas  = var.replicas
  affinity  = var.affinity
  template_spec = {
    containers = [
      {
        name  = var.name
        image = var.images.node_red
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          until mountpoint ${local.data_path}; do
          sleep 1
          done

          exec node-red \
            --port ${local.node_red_port} \
            --userDir "${local.data_path}"
          EOF
        ]
        env = concat([
          {
            name  = "HOME"
            value = local.data_path
          },
          ],
          [
            for key, value in var.extra_envs :
            {
              name = key
              valueFrom = {
                secretKeyRef = {
                  name = module.secret.name
                  key  = key
                }
              }
            }
          ]
        )
        securityContext = {
          runAsUser  = 1000
          runAsGroup = 1000
          fsGroup    = 1000
        }
        resources = var.resources
        ports = [
          {
            containerPort = local.node_red_port
          },
        ]
      },
    ]
    volumes = [
      {
        name = "config"
        secret = {
          secretName = module.secret.name
        }
      },
    ]
  }
}