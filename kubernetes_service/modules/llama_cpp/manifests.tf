locals {
  llama_cpp_port  = 8080
  models_path     = "/llama-cpp/models"
  llama_swap_path = "/llama-swap"
  config_file     = "/var/lib/llama-cpp/config.yaml"
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.release
  manifests = {
    "templates/statefulset.yaml" = module.statefulset.manifest
    "templates/service.yaml"     = module.service.manifest
    "templates/ingress.yaml"     = module.ingress.manifest
    "templates/secret.yaml"      = module.secret.manifest
  }
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = merge({
    basename(local.config_file) = yamlencode(var.llama_swap_config)
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
      host = var.ingress_hostname
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

module "statefulset" {
  source = "../../../modules/statefulset"

  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = 1
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  spec = {
    volumeClaimTemplates = [
      {
        metadata = {
          name = "models"
        }
        spec = {
          accessModes = [
            "ReadWriteOnce",
          ]
          storageClassName = var.storage_class_name
          resources = {
            requests = {
              storage = "120Gi"
            }
          }
        }
      },
    ]
  }
  template_spec = {
    resources = {
      requests = {
        memory = "8Gi"
      }
      limits = {
        memory = "96Gi" # GTT
      }
    }
    initContainers = [
      {
        name  = "${var.name}-rclone"
        image = var.images.rclone
        args = [
          "sync",
          "-v",
          ":s3:${var.minio_data_bucket}/",
          "${local.models_path}/",
        ]
        env = [
          {
            name  = "RCLONE_S3_ENDPOINT"
            value = var.minio_endpoint
          },
          {
            name = "AWS_ACCESS_KEY_ID"
            valueFrom = {
              secretKeyRef = {
                name = var.minio_access_secret
                key  = "AWS_ACCESS_KEY_ID"
              }
            }
          },
          {
            name = "AWS_SECRET_ACCESS_KEY"
            valueFrom = {
              secretKeyRef = {
                name = var.minio_access_secret
                key  = "AWS_SECRET_ACCESS_KEY"
              }
            }
          },
        ]
        volumeMounts = [
          {
            name      = "models"
            mountPath = local.models_path
          },
          {
            name      = "ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            readOnly  = true
          },
        ]
      },
      {
        name  = "${var.name}-llama-swap"
        image = var.images.llama_swap
        command = [
          "cp",
          "-r",
          "/app",
          "${local.llama_swap_path}/",
        ]
        volumeMounts = [
          {
            name      = "llama-swap"
            mountPath = local.llama_swap_path
          },
        ]
      },
    ]
    containers = [
      {
        name  = var.name
        image = var.images.llama_cpp
        command = [
          "${local.llama_swap_path}/app/llama-swap",
          "--config",
          "${local.config_file}",
          "--listen",
          "0.0.0.0:${local.llama_cpp_port}",
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.config_file
            subPath   = basename(local.config_file)
          },
          {
            name      = "llama-swap"
            mountPath = local.llama_swap_path
          },
          {
            name      = "models"
            mountPath = local.models_path
          },
        ]
        env = [
          for _, e in var.extra_envs :
          {
            name  = e.name
            value = tostring(e.value)
          }
        ]
        resources = {
          requests = {
            "amd.com/gpu" = 1
          }
          limits = {
            "amd.com/gpu" = 1
          }
        }
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
          initialDelaySeconds = 10
          timeoutSeconds      = 2
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
      {
        name = "llama-swap"
        emptyDir = {
          medium = "Memory"
        }
        # TODO: use image volume when stable
        # image = {
        #   reference  = var.images.llama_swap
        #   pullPolicy = "IfNotPresent"
        # }
      },
      {
        name = "ca-trust-bundle"
        hostPath = {
          path = "/etc/ssl/certs/ca-certificates.crt"
          type = "File"
        }
      },
    ]
  }
}