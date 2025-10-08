# Github actions runner #

resource "helm_release" "arc" {
  name             = "arc"
  repository       = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart            = "gha-runner-scale-set-controller"
  namespace        = "arc-systems"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  version          = "0.12.1"
  max_history      = 2
  values = [
    yamlencode({
      replicaCount = 3
      serviceAccount = {
        create = true
        name   = "gha-runner-scale-set-controller"
      }
      flags = {
        updateStrategy = "eventual"
      }
    }),
  ]
}

# ADR
# https://github.com/actions/actions-runner-controller/discussions/3152
# SETFCAP needed in runner workflow pod to build code-server and sunshine-desktop images

module "arc-workflow-secret" {
  source  = "../modules/secret"
  name    = "workflow-template"
  app     = "workflow-template"
  release = "0.1.0"
  data = {
    INTERNAL_CA_CERT = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem
    RENOVATE_TOKEN   = var.github.token # GITHUB_TOKEN cannot provide all permissions needed for renovate

    "workflow-podspec-builder.yaml" = yamlencode({
      spec = {
        labels = {
          app = "arc-runner"
        }
        containers = [
          {
            name = "$job"
            securityContext = {
              capabilities = {
                add = [
                  "SETFCAP",
                ]
              }
            }
            resources = {
              requests = {
                memory = "2Gi"
              }
              limits = {
                "squat.ai/kvm" = 1
              }
            }
            env = [
              {
                name = "INTERNAL_CA_CERT"
                valueFrom = {
                  secretKeyRef = {
                    name = "workflow-template"
                    key  = "INTERNAL_CA_CERT"
                  }
                }
              },

              # kaniko
              {
                name  = "INTERNAL_REGISTRY"
                value = "${local.endpoints.registry.service}:${local.service_ports.registry}"
              },
              {
                name  = "FF_KANIKO_SQUASH_STAGES" # https://github.com/mzihlmann/kaniko/pull/141
                value = "true"
              },

              # cosa
              {
                name = "MINIO_ACCESS_KEY_ID"
                valueFrom = {
                  secretKeyRef = {
                    name = local.minio_users.arc.secret
                    key  = "AWS_ACCESS_KEY_ID"
                  }
                }
              },
              {
                name = "MINIO_SECRET_ACCESS_KEY"
                valueFrom = {
                  secretKeyRef = {
                    name = local.minio_users.arc.secret
                    key  = "AWS_SECRET_ACCESS_KEY"
                  }
                }
              },
              {
                name  = "MC_HOST_arc"
                value = "https://$(MINIO_ACCESS_KEY_ID):$(MINIO_SECRET_ACCESS_KEY)@${local.services.cluster_minio.ip}:${local.service_ports.minio}"
              },
            ]
          },
        ]
      }
    })

    # renovate
    "workflow-podspec-renovate.yaml" = yamlencode({
      spec = {
        labels = {
          app = "arc-runner"
        }
        containers = [
          {
            name = "$job"
            resources = {
              requests = {
                memory = "2Gi"
              }
            }
            env = [
              {
                name = "RENOVATE_TOKEN"
                valueFrom = {
                  secretKeyRef = {
                    name = "workflow-template"
                    key  = "RENOVATE_TOKEN"
                  }
                }
              },
              {
                name  = "SSL_CERT_FILE"
                value = "/etc/ssl/certs/ca-certificates.crt"
              },
            ]
            volumeMounts = [
              {
                name      = "ca-bundle"
                mountPath = "/etc/ssl/certs/ca-certificates.crt"
                readOnly  = true
              },
            ]
          },
        ]
        volumes = [
          {
            name = "ca-bundle"
            hostPath = {
              path = "/etc/ssl/certs/ca-certificates.crt"
              type = "File"
            }
          },
        ]
      }
    })
  }
}

resource "helm_release" "arc-runner-hook-template" {
  name          = "arc-runner-hook-template"
  chart         = "../helm-wrapper"
  namespace     = "arc-runners"
  wait          = false
  wait_for_jobs = false
  max_history   = 2
  values = [
    yamlencode({
      manifests = [
        module.arc-workflow-secret.manifest,
      ]
    }),
  ]
}

data "github_repositories" "repos" {
  query = "user:${var.github.user} archived:false fork:true"
}

resource "helm_release" "arc-runner-set-builder" {
  for_each = toset(data.github_repositories.repos.names)

  name             = "builder-${each.key}"
  repository       = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart            = "gha-runner-scale-set"
  namespace        = "arc-runners"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  timeout          = 600
  version          = "0.12.1"
  max_history      = 2
  values = [
    yamlencode({
      githubConfigUrl = "https://github.com/${var.github.user}/${each.key}"
      githubConfigSecret = {
        github_token = var.github.token
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
              storage = "16Gi"
            }
          }
        }
      }
      template = {
        spec = {
          labels = {
            app = "arc-runner"
          }
          containers = [
            {
              name  = "runner"
              image = local.container_images.github_actions_runner
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
                  subPath   = "workflow-podspec-builder.yaml"
                },
              ]
            },
          ]
          volumes = [
            {
              name = "workflow-podspec-volume"
              secret = {
                secretName = "workflow-template"
              }
            },
          ]
        }
      }
      controllerServiceAccount = {
        namespace = "arc-systems"
        name      = "gha-runner-scale-set-controller"
      }
    }),
  ]
}

resource "helm_release" "arc-runner-set-renovate" {
  for_each = toset(data.github_repositories.repos.names)

  name             = "renovate-${each.key}"
  repository       = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart            = "gha-runner-scale-set"
  namespace        = "arc-runners"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  timeout          = 600
  version          = "0.12.1"
  max_history      = 2
  values = [
    yamlencode({
      githubConfigUrl = "https://github.com/${var.github.user}/${each.key}"
      githubConfigSecret = {
        github_token = var.github.token
      }
      maxRunners = 1
      containerMode = {
        type = "kubernetes"
        kubernetesModeWorkVolumeClaim = {
          accessModes = [
            "ReadWriteOnce",
          ]
          storageClassName = "local-path"
          resources = {
            requests = {
              storage = "16Gi"
            }
          }
        }
      }
      template = {
        spec = {
          labels = {
            app = "arc-runner"
          }
          containers = [
            {
              name  = "runner"
              image = local.container_images.github_actions_runner
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
                  subPath   = "workflow-podspec-renovate.yaml"
                },
              ]
            },
          ]
          volumes = [
            {
              name = "workflow-podspec-volume"
              secret = {
                secretName = "workflow-template"
              }
            },
          ]
        }
      }
      controllerServiceAccount = {
        namespace = "arc-systems"
        name      = "gha-runner-scale-set-controller"
      }
    }),
  ]
}