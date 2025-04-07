locals {
  data_path = "/var/lib/llama_cpp/models"
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.llama_cpp)[1]
  manifests = merge(module.mountpoint.chart.manifests, {
    "templates/service.yaml" = module.service.manifest
    "templates/ingress.yaml" = module.ingress.manifest
  })
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
        port       = var.ports.llama_cpp
        protocol   = "TCP"
        targetPort = var.ports.llama_cpp
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
          port    = var.ports.llama_cpp
          path    = "/"
        },
      ]
    },
  ]
}

module "mountpoint" {
  source = "../statefulset_mountpoint"
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
        image = var.images.llama_cpp
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          until mountpoint ${local.data_path}; do
          sleep 1
          done

          exec /app/llama-server \
            --no-webui \
            --host 0.0.0.0 \
            --port ${var.ports.llama_cpp}
          EOF
        ]
        env = concat([
          {
            name  = "MODEL_PATH"
            value = local.data_path
          },
          ], [
          for _, e in var.extra_envs :
          {
            name  = e.name
            value = tostring(e.value)
          }
        ])
        securityContext = var.security_context
        resources       = var.resources
        ports = [
          {
            containerPort = var.ports.llama_cpp
          },
        ]
      },
    ]
  }
}