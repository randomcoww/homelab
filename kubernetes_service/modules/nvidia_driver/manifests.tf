locals {
  init_path = "/usr/local/bin/nvidia-driver-drm"
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.nvidia_driver)[1]
  manifests = {
    "templates/daeonset.yaml"  = module.daemonset.manifest
    "templates/configmap.yaml" = module.configmap.manifest
    # "templates/poddisruptionbudget.yaml" = yamlencode({
    #   apiVersion = "policy/v1"
    #   kind       = "PodDisruptionBudget"
    #   metadata = {
    #     name = var.name
    #   }
    #   spec = {
    #     maxUnavailable             = 0
    #     unhealthyPodEvictionPolicy = "AlwaysAllow"
    #     selector = {
    #       matchLabels = {
    #         app = var.name
    #       }
    #     }
    #   }
    # })
  }
}

module "configmap" {
  source  = "../../../modules/configmap"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    basename(local.init_path) = file("${path.module}/templates/${basename(local.init_path)}")
  }
}

module "daemonset" {
  source  = "../../../modules/daemonset"
  name    = var.name
  app     = var.name
  release = var.release
  annotations = {
    "checksum/configmap" = sha256(module.configmap.manifest)
  }
  template_spec = {
    priorityClassName = "system-node-critical"
    containers = [
      {
        name  = var.name
        image = var.images.nvidia_driver
        command = [
          "bash",
          "-c",
          <<-EOF
          set -e

          echo -e "$INIT" > ${local.init_path}
          chmod +x ${local.init_path}
          exec ${local.init_path} init --accept-license
          EOF
        ]
        securityContext = {
          privileged = true
        }
        env = concat([
          for _, e in var.extra_envs :
          {
            name  = e.name
            value = tostring(e.value)
          }
          ], [
          {
            name = "INIT"
            valueFrom = {
              configMapKeyRef = {
                name = var.name
                key  = basename(local.init_path)
              }
            }
          },
        ])
        volumeMounts = [
          {
            name      = "var-log"
            mountPath = "/var/log"
          },
          {
            name             = "driver-root"
            mountPath        = "/run/nvidia"
            mountPropagation = "Bidirectional"
          },
        ]
      },
    ]
    volumes = [
      {
        name = "var-log"
        hostPath = {
          path = "/var/log"
        }
      },
      {
        name = "driver-root"
        hostPath = {
          path = "/run/nvidia"
        }
      },
    ]
  }
  affinity = {
    nodeAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = {
        nodeSelectorTerms = [
          {
            matchExpressions = [
              {
                key      = "feature.node.kubernetes.io/pci-10de.present"
                operator = "In"
                values = [
                  "true",
                ]
              },
            ]
          },
          {
            matchExpressions = [
              {
                key      = "feature.node.kubernetes.io/cpu-model.vendor_id"
                operator = "In"
                values = [
                  "NVIDIA",
                ]
              },
            ]
          },
          {
            matchExpressions = [
              {
                key      = "nvidia.com/gpu.present"
                operator = "In"
                values = [
                  "true",
                ]
              },
            ]
          },
        ]
      }
    }
  }
}