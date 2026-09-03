locals {
  models_path = "/models"
  config_file = "/var/lib/llama-cpp/config.yaml"
  models = [
    for k, image in var.image_volumes :
    {
      key   = k
      image = image.image
      file  = image.file
    }
  ]
}

module "secret" {
  source    = "../../../modules/secret"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = merge({
    basename(local.config_file) = yamlencode(merge(var.llama_swap_config, {
      macros = merge({
        model_path  = local.models_path
        default_cmd = <<-EOF
          llama-server \
          --port $${PORT} \
          --flash-attn on \
          --load-mode none
        EOF
        }, {
        for _, v in local.models :
        "${v.key}" => "${local.models_path}/${v.key}/${v.file}"
      })
      apiKeys = [
        for i, k in var.api_keys :
        "$${env.API_KEY_${i}}"
      ]
    }))
    }, {
    for i, k in var.api_keys :
    "API_KEY_${i}" => k
  })
}

module "service" {
  source    = "../../../modules/service"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = var.name
        port       = var.service_port
        protocol   = "TCP"
        targetPort = var.service_port
      },
    ]
  }
}

module "statefulset" {
  source = "../../../modules/statefulset"

  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  affinity  = var.affinity
  replicas  = var.replicas
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  labels = {
    for _, m in keys(lookup(var.llama_swap_config, "models", {})) :
    "model-${m}" => "true"
  }
  template_spec = {
    resourceClaims = [
      merge(var.gpu_resource_claim_ref, {
        name = "gpu"
      }),
    ]
    resources = merge({
      requests = {
        memory = "16Gi"
      }
    }, var.resources)
    containers = [
      {
        name  = var.name
        image = "${var.images.llama-swap.repository}:${var.images.llama-swap.tag}"
        command = [
          "llama-swap",
          "--config",
          "${local.config_file}",
          "--listen",
          "0.0.0.0:${var.service_port}",
        ]
        volumeMounts = concat([
          {
            name      = "config"
            mountPath = local.config_file
            subPath   = basename(local.config_file)
          },
          {
            name      = "ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            readOnly  = true
          },
          ], [
          for _, v in local.models :
          {
            name      = v.key
            mountPath = "${local.models_path}/${v.key}"
          }
        ])
        env = concat([
          for k, v in var.extra_envs :
          {
            name  = tostring(k)
            value = tostring(v)
          }
          ], [
          for i, _ in var.api_keys :
          {
            name = "API_KEY_${i}"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = "API_KEY_${i}"
              }
            }
          }
        ])
        resources = {
          claims = [
            {
              name = "gpu"
            },
          ]
        }
        ports = [
          {
            containerPort = var.service_port
          },
        ]
        livenessProbe = {
          httpGet = {
            port = var.service_port
            path = "/health"
          }
          initialDelaySeconds = 10
          timeoutSeconds      = 2
        }
        readinessProbe = {
          httpGet = {
            port = var.service_port
            path = "/health"
          }
        }
      },
    ]
    volumes = concat([
      {
        name = "config"
        secret = {
          secretName = module.secret.name
        }
      },
      {
        name = "ca-trust-bundle"
        hostPath = {
          path = "/etc/ssl/certs/ca-certificates.crt"
          type = "File"
        }
      },
      ], [
      for _, v in local.models :
      {
        name = v.key
        image = {
          reference = v.image
        }
      }
    ])
  }
}