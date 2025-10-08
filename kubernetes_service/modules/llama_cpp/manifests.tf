locals {
  llama_cpp_port = 8080
  model_path     = "/var/lib/llama_cpp/models"
  config_file    = "/var/lib/llama_cpp/config.yaml"
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.release
  manifests = merge(module.mountpoint.chart.manifests, {
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
  data = merge({
    "config.yaml" = yamlencode(var.llama_swap_config)
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
        port       = local.llama_cpp_port
        protocol   = "TCP"
        targetPort = local.llama_cpp_port
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
          port    = local.llama_cpp_port
          path    = "/"
        },
      ]
    },
  ]
}

# Mounting S3 path seems to be faster for model loading than using --model-url
module "mountpoint" {
  source = "../statefulset_mountpoint"
  ## s3 config
  s3_endpoint         = var.minio_endpoint
  s3_bucket           = var.minio_bucket
  s3_prefix           = ""
  s3_mount_path       = local.model_path
  s3_mount_extra_args = var.minio_mount_extra_args
  s3_access_secret    = var.minio_access_secret
  images = {
    mountpoint = var.images.mountpoint
  }
  ##
  name    = var.name
  app     = var.name
  release = var.release
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  affinity = var.affinity
  replicas = 1
  template_spec = {
    runtimeClassName = "nvidia-cdi"
    containers = [
      {
        name  = var.name
        image = var.images.llama_cpp
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e
          echo "Found driver $(nvidia-smi --query-gpu=driver_version --format=csv,noheader --id=0)"

          until mountpoint ${local.model_path}; do
          sleep 1
          done
          ln -sf "${local.model_path}" /models

          exec /app/llama-swap \
            --config ${local.config_file} \
            --listen 0.0.0.0:${local.llama_cpp_port}
          EOF
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.config_file
            subPath   = "config.yaml"
          },
        ]
        env = [
          for _, e in var.extra_envs :
          {
            name  = e.name
            value = tostring(e.value)
          }
        ]
        resources = var.resources
        ports = [
          {
            containerPort = local.llama_cpp_port
          },
        ]
        livenessProbe = {
          httpGet = {
            port = local.llama_cpp_port
            path = "/health"
          }
        }
        readinessProbe = {
          httpGet = {
            port = local.llama_cpp_port
            path = "/health"
          }
        }
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