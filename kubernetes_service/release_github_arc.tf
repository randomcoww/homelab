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
        yamlencode({
          apiVersion = "v1"
          kind       = "Secret"
          metadata = {
            name = "workflow-template"
          }
          stringData = {
            # GITHUB_TOKEN cannot provide all permissions needed for renovate
            RENOVATE_TOKEN   = var.github.token
            INTERNAL_CA_CERT = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem

            "workflow-podspec.yaml" = yamlencode({
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
                        name  = "INTERNAL_REGISTRY"
                        value = "${local.kubernetes_services.registry.endpoint}:${local.service_ports.registry}"
                      },
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
                        name  = "MC_ALIAS"
                        value = "arc"
                      },
                      {
                        name  = "MC_HOST_arc"
                        value = "https://$MINIO_ACCESS_KEY_ID:$MINIO_SECRET_ACCESS_KEY@${local.services.cluster_minio.ip}:${local.service_ports.minio}"
                      },
                    ]
                  },
                ]
                volumes = [
                  {
                    name = "workflow-template"
                    secret = {
                      secretName = "workflow-template"
                    }
                  },
                ]
              }
            })
          }
        }),
      ]
    })
  ]
}

data "github_repositories" "repos" {
  query = "user:${var.github.user} archived:false fork:true"
}

resource "helm_release" "arc-runner-set" {
  for_each = toset(data.github_repositories.repos.names)

  name             = "arc-runner-${each.key}"
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
                  subPath   = "workflow-podspec.yaml"
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
  depends_on = [
    kubernetes_labels.labels,
    helm_release.arc,
    helm_release.arc-runner-hook-template,
  ]
}