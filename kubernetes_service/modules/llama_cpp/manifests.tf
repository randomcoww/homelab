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
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  affinity  = var.affinity
  replicas  = 1
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
          ln -sf "${local.data_path}" /models

          exec /app/llama-server \
            --no-webui \
            --host 0.0.0.0 \
            --port ${var.ports.llama_cpp} $@
          EOF
        ]
        args = var.args
        env = [
          for _, e in var.extra_envs :
          {
            name  = e.name
            value = tostring(e.value)
          }
        ]
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