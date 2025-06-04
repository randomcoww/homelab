# Github actions runner #

locals {
  github_arc_mc_config_dir = "/var/tmp/minio"
}

resource "helm_release" "arc" {
  name             = "arc"
  repository       = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart            = "gha-runner-scale-set-controller"
  namespace        = "arc-systems"
  create_namespace = true
  wait             = false
  version          = "0.11.0"
  max_history      = 2
  values = [
    yamlencode({
      serviceAccount = {
        create = true
        name   = "gha-runner-scale-set-controller"
      }
    }),
  ]
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
        Action = "*"
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

# ADR
# https://github.com/actions/actions-runner-controller/discussions/3152
# SETFCAP needed in runner workflow pod to build code-server and sunshine-desktop images
resource "helm_release" "arc-runner-hook-template" {
  name        = "arc-runner-hook-template"
  chart       = "../helm-wrapper"
  namespace   = "arc-runners"
  wait        = false
  max_history = 2
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
            AWS_ENDPOINT_URL_S3   = "https://${data.terraform_remote_state.sr.outputs.backend_bucket.url}"
            AWS_ACCESS_KEY_ID     = data.terraform_remote_state.sr.outputs.backend_bucket.access_key_id
            AWS_SECRET_ACCESS_KEY = data.terraform_remote_state.sr.outputs.backend_bucket.secret_access_key
            minio_ca_cert         = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem
            minio_config = jsonencode({
              aliases = {
                arc = {
                  url       = "https://${local.kubernetes_services.minio.endpoint}:${local.service_ports.minio}"
                  accessKey = minio_iam_user.arc.id
                  secretKey = minio_iam_user.arc.secret
                  api       = "S3v4"
                  path      = "auto"
                }
              }
            })
            "workflow-podspec.yaml" = yamlencode({
              spec = {
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
                        memory                    = "2Gi"
                        "devices.kubevirt.io/kvm" = "1"
                      }
                      limits = {
                        "devices.kubevirt.io/kvm" = "1"
                      }
                    }
                    env = concat([
                      for _, key in [
                        "AWS_ENDPOINT_URL_S3",
                        "AWS_ACCESS_KEY_ID",
                        "AWS_SECRET_ACCESS_KEY",
                      ] :
                      {
                        name = key
                        valueFrom = {
                          secretKeyRef = {
                            name = "workflow-template"
                            key  = key
                          }
                        }
                      }
                      ], [
                      {
                        name  = "MC_CONFIG_DIR"
                        value = local.github_arc_mc_config_dir
                      },
                    ])
                    volumeMounts = [
                      {
                        name      = "mc-config-dir"
                        mountPath = local.github_arc_mc_config_dir
                      },
                      {
                        name      = "workflow-template"
                        mountPath = "${local.github_arc_mc_config_dir}/certs/CAs/ca.crt"
                        subPath   = "minio_ca_cert"
                      },
                      {
                        name      = "workflow-template"
                        mountPath = "${local.github_arc_mc_config_dir}/config.json"
                        subPath   = "minio_config"
                      },
                    ]
                  },
                ]
                volumes = [
                  {
                    name = "mc-config-dir"
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
    "kvm-device-plugin",
    "mountpoint-s3",
    "s3fs",
    "kubernetes",
    "steamcmd",
    "qrcode-generator",
    "code-server",
    "sunshine-desktop",
    "fedora-coreos-config",
    "tailscale-nft",
    "nvidia-driver-container",
    "homelab",
    "stork-agent",
    "litestream",
  ])

  name             = "arc-runner-${each.key}"
  repository       = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart            = "gha-runner-scale-set"
  namespace        = "arc-runners"
  create_namespace = true
  wait             = false
  version          = "0.11.0"
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
          containers = [
            {
              name  = "runner"
              image = "ghcr.io/actions/actions-runner:latest"
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
}