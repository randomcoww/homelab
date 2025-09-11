module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.device_plugin)[1]
  manifests = {
    "templates/daeonset.yaml" = module.daemonset.manifest
  }
}

module "daemonset" {
  source  = "../../../modules/daemonset"
  name    = var.name
  app     = var.name
  release = var.release
  annotations = {
    "prometheus.io/scrape" = "true"
    "prometheus.io/port"   = tostring(var.ports.device_plugin_metrics)
  }
  template_spec = {
    priorityClassName = "system-node-critical"
    containers = [
      {
        name  = var.name
        image = var.images.device_plugin
        args = concat(var.args, [
          "--listen=0.0.0.0:${var.ports.device_plugin_metrics}",
          "--plugin-directory=${var.kubelet_root_path}/device-plugins",
        ])
        securityContext = {
          privileged = true
        }
        ports = [
          {
            containerPort = var.ports.device_plugin_metrics
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