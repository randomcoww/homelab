# Github actions runner #

locals {
  arc_mc_config_dir = "/minio"
}

resource "minio_iam_user" "arc" {
  name          = "arc"
  force_destroy = true
}

resource "minio_iam_policy" "arc" {
  name = "arc"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload",
        ]
        Resource = [
          minio_s3_bucket.data["boot"].arn,
          "${minio_s3_bucket.data["boot"].arn}/*",
        ]
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "arc" {
  user_name   = minio_iam_user.arc.id
  policy_name = minio_iam_policy.arc.id
}

resource "helm_release" "arc" {
  name             = "arc"
  repository       = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart            = "gha-runner-scale-set-controller"
  namespace        = "arc-systems"
  create_namespace = true
  wait             = true
  wait_for_jobs    = true
  timeout          = 600
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
  wait          = true
  wait_for_jobs = true
  timeout       = 600
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
            INTERNAL_CA_CERT = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem
            minio_config = jsonencode({
              aliases = {
                arc = {
                  url       = "https://${local.services.cluster_minio.ip}:${local.service_ports.minio}"
                  accessKey = minio_iam_user.arc.id
                  secretKey = minio_iam_user.arc.secret
                  api       = "S3v4"
                  path      = "auto"
                }
              }
            })
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
                        name  = "MC_CONFIG_DIR"
                        value = local.arc_mc_config_dir
                      },
                    ]
                    volumeMounts = [
                      {
                        name      = "minio-path"
                        mountPath = local.arc_mc_config_dir
                      },
                      {
                        name      = "workflow-template"
                        mountPath = "${local.arc_mc_config_dir}/certs/CAs/ca.crt"
                        subPath   = "internal_ca_cert"
                      },
                      {
                        name      = "workflow-template"
                        mountPath = "${local.arc_mc_config_dir}/config.json"
                        subPath   = "minio_config"
                      },
                    ]
                  },
                ]
                volumes = [
                  {
                    name = "minio-path"
                    emptyDir = {
                      medium = "Memory"
                    }
                  },
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

resource "helm_release" "arc-runner-set" {
  for_each = toset([
    "etcd-wrapper",
    "kapprover",
    "ipxe",
    "hostapd-noscan",
    "kea",
    "mountpoint-s3",
    "kubernetes",
    "qrcode-generator",
    "sunshine-desktop",
    "fedora-coreos-config",
    "tailscale-nft",
    "nvidia-driver-container",
    "homelab",
    "stork-agent",
    "llama-cpp-server-cuda",
    "litestream",
    "kaniko",
    "code-server",
    "juicefs",
    "audioserve",
  ])

  name             = "arc-runner-${each.key}"
  repository       = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart            = "gha-runner-scale-set"
  namespace        = "arc-runners"
  create_namespace = true
  wait             = true
  timeout          = 600
  version          = "0.12.1"
  max_history      = 2
  values = [
    yamlencode({
      githubConfigUrl = "https://github.com/randomcoww/${each.key}"
      githubConfigSecret = {
        github_token = var.github.arc_token
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
              storage = "2Gi"
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
    helm_release.arc,
    helm_release.arc-runner-hook-template,
  ]
  lifecycle {
    replace_triggered_by = [
      helm_release.arc,
    ]
  }
}