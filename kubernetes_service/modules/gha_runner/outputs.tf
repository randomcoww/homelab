output "flux_manifests" {
  value = [
    for _, m in concat([
      # resources
      {
        apiVersion = "source.toolkit.fluxcd.io/v1"
        kind       = "HelmRepository"
        metadata = {
          name      = "${var.name}-resources"
          namespace = var.runner_namespace
        }
        spec = {
          interval = "15m"
          url      = "https://randomcoww.github.io/homelab/"
        }
      },
      {
        apiVersion = "helm.toolkit.fluxcd.io/v2"
        kind       = "HelmRelease"
        metadata = {
          name      = "${var.name}-resources"
          namespace = var.runner_namespace
        }
        spec = {
          interval = "15m"
          timeout  = "5m"
          chart = {
            spec = {
              chart = "helm-wrapper"
              sourceRef = {
                kind = "HelmRepository"
                name = "${var.name}-resources"
              }
              interval = "5m"
            }
          }
          releaseName = "${var.name}-resources"
          install = {
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
            manifests = [
              module.tls.manifest,
              module.workflow-config.manifest,
            ]
          }
        }
      },

      # repos
      {
        apiVersion = "source.toolkit.fluxcd.io/v1"
        kind       = "OCIRepository"
        metadata = {
          name      = "${var.name}-scale-set-controller"
          namespace = var.namespace
        }
        spec = {
          interval = "15m"
          url      = "oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller"
          ref = {
            tag = "0.14.0" # renovate: datasource=docker depName=oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
          }
        }
      },
      {
        apiVersion = "source.toolkit.fluxcd.io/v1"
        kind       = "OCIRepository"
        metadata = {
          name      = "${var.name}-scale-set"
          namespace = var.runner_namespace
        }
        spec = {
          interval = "15m"
          url      = "oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set"
          ref = {
            tag = "0.14.0" # renovate: datasource=docker depName=oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
          }
        }
      },

      # controller
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
            name      = "${var.name}-scale-set-controller"
            namespace = var.namespace
          }
          releaseName = var.name
          install = {
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
            replicaCount = 2
            serviceAccount = {
              create = true
              name   = local.service_account_name
            }
            flags = {
              updateStrategy = "eventual"
            }
            resources = {
              requests = {
                memory = "128Mi"
              }
              limits = {
                memory = "128Mi"
              }
            }
          }
        }
      },
      ], [
      # scale sets by workflow and repo
      for k in flatten([
        for workflow, repos in {
          "renovate" = [
            "homelab",
            "container-builds",
            "fedora-coreos-config-custom",
            "etcd-wrapper",
          ]
          "kaniko" = [
            "container-builds",
            "etcd-wrapper",
          ]
          "cosa" = [
            "fedora-coreos-config-custom",
          ]
          } : [
          for repo in repos : {
            repo = repo
            name = "${workflow}-${repo}"
            spec = "workflow-podspec-${workflow}.yaml"
          }
        ]
      ]) :
      {
        apiVersion = "helm.toolkit.fluxcd.io/v2"
        kind       = "HelmRelease"
        metadata = {
          name      = "${var.name}-${k.name}"
          namespace = var.runner_namespace
        }
        spec = {
          interval = "15m"
          timeout  = "5m"
          chartRef = {
            kind      = "OCIRepository"
            name      = "${var.name}-scale-set"
            namespace = var.runner_namespace
          }
          releaseName = k.name # should match runner name in github jobs
          install = {
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
            githubConfigUrl = "https://github.com/${var.github_credentials.username}/${k.repo}"
            githubConfigSecret = {
              github_token = var.github_credentials.token
            }
            maxRunners = 3
            containerMode = {
              type = "kubernetes"
              kubernetesModeWorkVolumeClaim = {
                accessModes = [
                  "ReadWriteOnce",
                ]
                storageClassName = "local-path"
                resources = {
                  requests = {
                    storage = "64Gi"
                  }
                }
              }
            }
            template = {
              spec = {
                containers = [
                  {
                    name  = "runner"
                    image = var.images.gha_runner
                    command = [
                      "/home/runner/run.sh",
                    ]
                    env = [
                      {
                        name  = "ACTIONS_RUNNER_CONTAINER_HOOK_TEMPLATE"
                        value = "/home/runner/config/workflow-podspec.yaml"
                      },
                    ]
                    volumeMounts = [
                      {
                        name      = "workflow-podspec-volume"
                        mountPath = "/home/runner/config/workflow-podspec.yaml"
                        subPath   = k.spec
                      },
                    ]
                  },
                ]
                volumes = [
                  {
                    name = "workflow-podspec-volume"
                    configMap = {
                      name = module.workflow-config.name
                    }
                  },
                ]
              }
            }
            controllerServiceAccount = {
              namespace = var.namespace
              name      = local.service_account_name
            }
          }
        }
      }
    ]) :
    yamlencode(m)
  ]
}