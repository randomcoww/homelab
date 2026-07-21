output "manifests" {
  value = concat([
    # runner resources in arc-runners
    module.user-secret.manifest,
    module.workflow-config.manifest,

    ], [
    for _, m in concat([

      # runner in arc-runners
      {
        apiVersion = "source.toolkit.fluxcd.io/v1"
        kind       = "OCIRepository"
        metadata = {
          name      = "${var.name}-scale-set"
          namespace = var.namespace
        }
        spec = {
          interval = "15m"
          url      = "oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set"
          ref = {
            tag = "0.14.2" # renovate: datasource=docker depName=ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set depType=helm_regex
          }
        }
      },
      ], [
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
          "kaniko-high-memory" = [
            "container-builds",
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
          namespace = var.namespace
        }
        spec = {
          interval = "15m"
          timeout  = "5m"
          chartRef = {
            kind      = "OCIRepository"
            name      = "${var.name}-scale-set"
            namespace = var.namespace
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
            maxRunners = 2
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
              namespace = var.controller_namespace
              name      = local.service_account_name
            }
          }
        }
      }
      ], [

      # runner-controller in arc-systems
      {
        apiVersion = "source.toolkit.fluxcd.io/v1"
        kind       = "OCIRepository"
        metadata = {
          name      = "${var.name}-scale-set-controller"
          namespace = var.controller_namespace
        }
        spec = {
          interval = "15m"
          url      = "oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller"
          ref = {
            tag = "0.14.2" # renovate: datasource=docker depName=ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller depType=helm_regex
          }
        }
      },
      {
        apiVersion = "helm.toolkit.fluxcd.io/v2"
        kind       = "HelmRelease"
        metadata = {
          name      = var.name
          namespace = var.controller_namespace
        }
        spec = {
          interval = "15m"
          timeout  = "5m"
          chartRef = {
            kind      = "OCIRepository"
            name      = "${var.name}-scale-set-controller"
            namespace = var.controller_namespace
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
            }
          }
        }
      },

      # client cert
      {
        apiVersion = "cert-manager.io/v1"
        kind       = "Certificate"
        metadata = {
          name      = "${var.name}-client-tls"
          namespace = var.namespace
        }
        spec = {
          secretName = "${var.name}-client-tls"
          isCA       = false
          privateKey = {
            algorithm = "ECDSA"
            size      = 521
          }
          commonName = var.name
          usages = [
            "key encipherment",
            "digital signature",
            "client auth",
          ]
          issuerRef = {
            name = var.ca_issuer_name
            kind = "ClusterIssuer"
          }
        }
      },
    ]) :
    yamlencode(m)
  ])
}