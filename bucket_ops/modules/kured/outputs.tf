output "manifests" {
  value = concat([
    module.configmap.manifest,
    ], [
    for _, m in [
      {
        apiVersion = "source.toolkit.fluxcd.io/v1"
        kind       = "OCIRepository"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          interval = "6h"
          url      = "oci://ghcr.io/kubereboot/charts/kured"
          ref = {
            tag = "6.1.0" # renovate: datasource=docker depName=ghcr.io/kubereboot/charts/kured depType=helm_regex
          }
        }
      },
      {
        apiVersion = "helm.toolkit.fluxcd.io/v2"
        kind       = "HelmRelease"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          interval = "15m"
          timeout  = "5m"
          chartRef = {
            kind      = "OCIRepository"
            name      = var.name
            namespace = var.namespace
          }
          releaseName = var.name
          install = {
            createNamespace = true
            remediation = {
              retries = -1
            }
          }
          upgrade = {
            remediation = {
              retries = -1
            }
          }
          test = {
            enable = false
          }
          values = {
            # manifest #

            image = {
              repository = var.images.kured.repository
              tag        = var.images.kured.tag
            }
            podAnnotations = {
              "checksum/configmap" = sha256(module.configmap.manifest)
            }
            configuration = merge({
              period       = "2m"
              forceReboot  = true
              drainTimeout = "6m"
              # trigger reboot if either /var/run/reboot-required is set, or node failed network boot
              useRebootSentinelHostPath = false
              rebootSentinelCommand     = "reboot-required.sh"
            }, var.kured_config)
            resources = {
              requests = {
                memory = "64Mi"
              }
              limits = {
                memory = "96Mi"
              }
            }
            priorityClassName = "system-node-critical"
            metrics = {
              create    = true
              namespace = var.namespace
            }
            service = {
              create = true
            }
            volumes = [
              {
                name = "config"
                configMap = {
                  name = module.configmap.name
                }
              },
              {
                name = "config-mount"
                hostPath = {
                  path = dirname(local.reboot_required_host_file)
                  type = "DirectoryOrCreate"
                }
              },
            ]
            initContainers = [
              {
                name  = "kured-config"
                image = "${var.images.kured.repository}:${var.images.kured.tag}"
                command = [
                  "sh",
                  "-c",
                  <<-EOF
                  cp "/var/tmp/${basename(local.reboot_required_host_file)}" \
                  "${local.reboot_required_host_file}"
                  chmod 755 "${local.reboot_required_host_file}"
                  EOF
                ]
                volumeMounts = [
                  {
                    name      = "config-mount"
                    mountPath = dirname(local.reboot_required_host_file)
                  },
                  {
                    name      = "config"
                    mountPath = "/var/tmp/${basename(local.reboot_required_host_file)}"
                    subPath   = basename(local.reboot_required_host_file)
                  },
                ]
              },
            ]
          }
        }
      },

      # NS
      {
        apiVersion = "v1"
        kind       = "Namespace"
        metadata = {
          name = var.namespace
          annotations = {
            "kustomize.toolkit.fluxcd.io/prune" = "disabled"
          }
        }
      },
    ] :
    yamlencode(m)
  ])
}