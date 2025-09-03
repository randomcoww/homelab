locals {
  model_path  = "/var/lib/llama_cpp/models"
  config_path = "/var/lib/llama_cpp/config.yaml"
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
    "templates/secret.yaml"  = module.secret.manifest
  })
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = merge({
    basename(local.config_path) = yamlencode(var.llama_swap_config)
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

# Mounting S3 path seems to be faster for model loading than using --model-url
module "mountpoint" {
  source = "../statefulset_mountpoint"
  ## s3 config
  s3_endpoint          = var.s3_endpoint
  s3_bucket            = var.s3_bucket
  s3_prefix            = ""
  s3_access_key_id     = var.s3_access_key_id
  s3_secret_access_key = var.s3_secret_access_key
  s3_mount_path        = local.model_path
  s3_mount_extra_args  = var.s3_mount_extra_args
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

          until mountpoint ${local.model_path}; do
          sleep 1
          done
          ln -sf "${local.model_path}" /models

          exec /tini -- /app/llama-swap \
            --config ${local.config_path} \
            --listen 0.0.0.0:${var.ports.llama_cpp}
          EOF
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.config_path
            subPath   = basename(local.config_path)
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
            containerPort = var.ports.llama_cpp
          },
        ]
        livenessProbe = {
          httpGet = {
            port = var.ports.llama_cpp
            path = "/health"
          }
        }
        readinessProbe = {
          httpGet = {
            port = var.ports.llama_cpp
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