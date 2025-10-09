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
  ]
  kubelet_root_path = local.kubernetes.kubelet_root_path
}

# Nvidia GPU

resource "helm_release" "nvidia-gpu-oprerator" {
  name             = "gpu-operator"
  namespace        = "nvidia"
  create_namespace = true
  repository       = "https://helm.ngc.nvidia.com/nvidia"
  chart            = "gpu-operator"
  wait             = false
  wait_for_jobs    = false
  version          = "v25.3.4"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      cdi = {
        enabled = true
        default = true
      }
      # Operator automatically appends -<osrelease> to end of tag. E.g. :<version>-fedora42
      driver = {
        kernelModuleType = "open"
        repository       = regex(local.container_image_regex, local.container_images.nvidia_driver).repository
        image            = regex(local.container_image_regex, local.container_images.nvidia_driver).image
        version          = regex(local.container_image_regex, local.container_images.nvidia_driver).version
        upgradePolicy = {
          gpuPodDeletion = {
            force          = true
            deleteEmptyDir = true
          }
        }
      }
      toolkit = {
        enabled = true
      }
      devicePlugin = {
        enabled = true
      }
      dcgmExporter = {
        enabled = false
      }
      migManager = {
        enabled = false
      }
      vgpuDeviceManager = {
        enabled = false
      }
      vfioManager = {
        enabled = false
      }
      node-feature-discovery = {
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
  version          = "0.20.0"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      nfd = {
        enabled = false
      }
      labeller = {
        enabled = false
      }
    })
  ]
}