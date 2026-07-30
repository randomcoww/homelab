locals {
  metrics_port = 9100
}

module "daemonset" {
  source    = "../../../modules/daemonset"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  template_spec = {
    priorityClassName = "system-node-critical"
    resources = {
      requests = {
        memory = "64Mi"
      }
      limits = {
        memory = "64Mi"
      }
    }
    containers = [
      {
        name  = var.name
        image = var.images.device_plugin
        args = concat(var.args, [
          "--listen=0.0.0.0:${local.metrics_port}",
          "--plugin-directory=${var.kubelet_root_path}/device-plugins",
        ])
        securityContext = {
          privileged = true
        }
        ports = [
          {
            containerPort = local.metrics_port
          },
        ]
        volumeMounts = [
          {
            name      = "device-plugin"
            mountPath = "${var.kubelet_root_path}/device-plugins"
          },
          {
            name      = "dev"
            mountPath = "/dev"
          },
        ]
      },
    ]
    volumes = [
      {
        name = "device-plugin"
        hostPath = {
          path = "${var.kubelet_root_path}/device-plugins"
        }
      },
      {
        name = "dev"
        hostPath = {
          path = "/dev"
        }
      },
    ]
    tolerations = [
      {
        key      = "node.kubernetes.io/not-ready"
        operator = "Exists"
        effect   = "NoExecute"
      },
      {
        key      = "node.kubernetes.io/unreachable"
        operator = "Exists"
        effect   = "NoExecute"
      },
      {
        key      = "node.kubernetes.io/disk-pressure"
        operator = "Exists"
        effect   = "NoSchedule"
      },
      {
        key      = "node.kubernetes.io/memory-pressure"
        operator = "Exists"
        effect   = "NoSchedule"
      },
      {
        key      = "node.kubernetes.io/pid-pressure"
        operator = "Exists"
        effect   = "NoSchedule"
      },
      {
        key      = "node.kubernetes.io/unschedulable"
        operator = "Exists"
        effect   = "NoSchedule"
      },
    ]
  }
}