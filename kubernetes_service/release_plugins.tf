# Generic device plugin

module "device-plugin" {
  source    = "./modules/device_plugin"
  name      = "device-plugin"
  namespace = "kube-system"
  release   = "0.1.0"
  images = {
    device_plugin = local.container_images.device_plugin
  }
  ports = {
    device_plugin_metrics = local.service_ports.metrics
  }
  args = [
    "--device",
    yamlencode({
      name = "rfkill"
      groups = [
        {
          count = 100
          paths = [
            {
              path = "/dev/rfkill"
            },
          ]
        },
      ]
    }),
    "--device",
    yamlencode({
      name = "kvm"
      groups = [
        {
          count = 100
          paths = [
            {
              path = "/dev/kvm"
            },
          ]
        },
      ]
    }),
    "--device",
    yamlencode({
      name = "fuse"
      groups = [
        {
          count = 100
          paths = [
            {
              path = "/dev/fuse"
            },
          ]
        },
      ]
    }),
    "--device",
    yamlencode({
      name = "ntsync"
      groups = [
        {
          count = 100
          paths = [
            {
              path = "/dev/ntsync"
            },
          ]
        },
      ]
    }),
    "--device",
    yamlencode({
      name = "uinput"
      groups = [
        {
          count = 100
          paths = [
            {
              path = "/dev/uinput"
            },
          ]
        },
      ]
    }),
    "--device",
    yamlencode({
      name = "input"
      groups = [
        {
          count = 100
          paths = [
            {
              path = "/dev/input"
              type = "Mount"
            },
          ]
        },
      ]
    }),
  ]
  kubelet_root_path = local.kubernetes.kubelet_root_path
}

# Node feature discovery

resource "helm_release" "node-feature-discovery" {
  name             = "node-feature-discovery"
  namespace        = "kube-system"
  repository       = "oci://gcr.io/k8s-staging-nfd/charts"
  chart            = "node-feature-discovery"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  version          = "0.18.3"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      master = {
        replicaCount = 2
      }
      worker = {
        config = {
          sources = {
            custom = [
              {
                name = "hostapd-compat"
                labels = {
                  hostapd-compat = true
                }
                matchFeatures = [
                  {
                    feature = "kernel.loadedmodule"
                    matchName = {
                      op = "InRegexp",
                      value = [
                        "^rtw8",
                        "^mt7",
                      ]
                    }
                  },
                ]
              },
            ]
          }
        }
      }
    })
  ]
}

# AMD GPU

resource "helm_release" "amd-gpu" {
  name             = "amd-gpu"
  namespace        = "amd"
  create_namespace = true
  repository       = "https://rocm.github.io/k8s-device-plugin/"
  chart            = "amd-gpu"
  wait             = false
  wait_for_jobs    = false
  version          = "0.21.0"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      nfd = {
        enabled = false
      }
      labeller = {
        enabled = true
      }
      dp = {
        resources = {
          requests = {
            memory = "64Mi"
          }
          limits = {
            memory = "64Mi"
          }
        }
      }
      lbl = {
        resources = {
          requests = {
            memory = "64Mi"
          }
          limits = {
            memory = "64Mi"
          }
        }
      }
    })
  ]
}