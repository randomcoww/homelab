module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.fuse_device_plugin)[1]
  manifests = {
    "templates/daeonset.yaml" = module.daemonset.manifest
  }
}

module "daemonset" {
  source  = "../../../modules/daemonset"
  name    = var.name
  app     = var.name
  release = var.release
  template_spec = {
    hostNetwork       = true
    priorityClassName = "system-node-critical"
    dnsPolicy         = "ClusterFirstWithHostNet"
    containers = [
      {
        name  = var.name
        image = var.images.fuse_device_plugin
        securityContext = {
          allowPrivilegeEscalation = false
          capabilities = {
            drop = [
              "ALL",
            ]
          },
        }
        volumeMounts = [
          {
            name      = "device-plugin"
            mountPath = "${var.kubelet_root_path}/device-plugins"
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