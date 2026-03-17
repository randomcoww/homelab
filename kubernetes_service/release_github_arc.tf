# Github actions runner

resource "helm_release" "arc" {
  name             = "arc"
  repository       = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart            = "gha-runner-scale-set-controller"
  namespace        = "arc-systems"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  version          = "0.13.1"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      replicaCount = 2
      serviceAccount = {
        create = true
        name   = "gha-runner-scale-set-controller"
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
    }),
  ]
}

resource "tls_private_key" "registry-client" {
  algorithm   = data.terraform_remote_state.sr.outputs.trust.ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = 4096
}

resource "tls_cert_request" "registry-client" {
  private_key_pem = tls_private_key.registry-client.private_key_pem

  subject {
    common_name = local.endpoints.registry.service
  }
}

resource "tls_locally_signed_cert" "registry-client" {
  cert_request_pem   = tls_cert_request.registry-client.cert_request_pem
  ca_private_key_pem = data.terraform_remote_state.sr.outputs.trust.ca.private_key_pem
  ca_cert_pem        = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

module "registry-tls" {
  source  = "../modules/secret"
  name    = "registry-tls"
  app     = "registry-tls"
  release = "0.1.0"
  data = {
    "tls.crt" = tls_locally_signed_cert.registry-client.cert_pem
    "tls.key" = tls_private_key.registry-client.private_key_pem
    "ca.crt"  = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem
  }
}

module "arc-workflow-secret" {
  source  = "../modules/secret"
  name    = "workflow-template"
  app     = "workflow-template"
  release = "0.1.0"
  data = {
    INTERNAL_CA_CERT = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem
    RENOVATE_TOKEN   = var.github.token # GITHUB_TOKEN cannot provide all permissions needed for renovate

    # ADR
    # https://github.com/actions/actions-runner-controller/discussions/3152

    # kaniko container build
    "workflow-podspec-kaniko.yaml" = yamlencode({
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
                  "SETFCAP", # needed to build code-server and sunshine-desktop images
                ]
              }
            }
            env = [
              {
                name = "INTERNAL_CA_CERT" # add to some builds such as iPXE
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
                value = local.service_ports.registry == 443 ? local.endpoints.registry.service : "${local.endpoints.registry.service}:${local.service_ports.registry}"
              },
              {
                name  = "FF_KANIKO_SQUASH_STAGES" # https://github.com/mzihlmann/kaniko/pull/141
                value = "true"
              },
              {
                name  = "SSL_CERT_DIR"
                value = "/kaniko/ssl/certs"
              },
              {
                name  = "DOCKER_CONFIG"
                value = "/kaniko/.docker"
              },
            ]
            # ** Don't mount volumes outside of /kaniko to this container **
            # Volumes can interfere with container build process if the same resource is being used in the build
            # Use paths from https://github.com/osscontainertools/kaniko/blob/main/deploy/Dockerfile
            volumeMounts = [
              {
                name      = "ca-trust-bundle"
                mountPath = "/kaniko/ssl/certs/ca-certificates.crt"
                readOnly  = true
              },
              {
                name      = "registry-tls"
                mountPath = "/kaniko/.docker/ca.crt"
                subPath   = "ca.crt"
              },
              {
                name      = "registry-tls"
                mountPath = "/kaniko/.docker/client.cert"
                subPath   = "tls.crt"
              },
              {
                name      = "registry-tls"
                mountPath = "/kaniko/.docker/client.key"
                subPath   = "tls.key"
              },
            ]
          },
        ]
        volumes = [
          {
            name = "ca-trust-bundle"
            hostPath = {
              path = "/etc/ssl/certs/ca-certificates.crt"
              type = "File"
            }
          },
          {
            name = "registry-tls"
            secret = {
              secretName = module.registry-tls.name
            }
          },
        ]
      }
    })

    # cosa build
    "workflow-podspec-cosa.yaml" = yamlencode({
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
                memory          = "4Gi"
                "squat.ai/kvm"  = 1
                "squat.ai/fuse" = 1
              }
              limits = {
                memory          = "8Gi"
                "squat.ai/kvm"  = 1
                "squat.ai/fuse" = 1
              }
            }
            env = [
              {
                name = "INTERNAL_CA_CERT" # feed to OS image build
                valueFrom = {
                  secretKeyRef = {
                    name = "workflow-template"
                    key  = "INTERNAL_CA_CERT"
                  }
                }
              },
              {
                name  = "RCLONE_S3_ENDPOINT"
                value = "${local.services.cluster_minio.ip}:${local.service_ports.minio}"
              },
              {
                name = "AWS_ACCESS_KEY_ID"
                valueFrom = {
                  secretKeyRef = {
                    name = local.minio_users.arc.secret
                    key  = "AWS_ACCESS_KEY_ID"
                  }
                }
              },
              {
                name = "AWS_SECRET_ACCESS_KEY"
                valueFrom = {
                  secretKeyRef = {
                    name = local.minio_users.arc.secret
                    key  = "AWS_SECRET_ACCESS_KEY"
                  }
                }
              },
            ]
            volumeMounts = [
              {
                name      = "ca-trust-bundle"
                mountPath = "/etc/ssl/certs/ca-certificates.crt"
                readOnly  = true
              },
            ]
          },
        ]
        volumes = [
          {
            name = "ca-trust-bundle"
            hostPath = {
              path = "/etc/ssl/certs/ca-certificates.crt"
              type = "File"
            }
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
              limits = {
                memory = "4Gi"
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
              {
                # Set certs for internal registry from env
                # https://docs.renovatebot.com/self-hosted-configuration/#detecthostrulesfromenv
                name  = "RENOVATE_DETECT_HOST_RULES_FROM_ENV"
                value = "true"
              },
              {
                name = "DOCKER_${upper(replace(local.endpoints.registry.service, "/[.-]/", "_"))}_HTTPSCERTIFICATE"
                valueFrom = {
                  secretKeyRef = {
                    name = "registry-tls"
                    key  = "tls.crt"
                  }
                }
              },
              {
                name = "DOCKER_${upper(replace(local.endpoints.registry.service, "/[.-]/", "_"))}_HTTPSPRIVATEKEY"
                valueFrom = {
                  secretKeyRef = {
                    name = "registry-tls"
                    key  = "tls.key"
                  }
                }
              },
              {
                name = "DOCKER_${upper(replace(local.endpoints.registry.service, "/[.-]/", "_"))}_HTTPSCERTIFICATEAUTHORITY"
                valueFrom = {
                  secretKeyRef = {
                    name = "registry-tls"
                    key  = "ca.crt"
                  }
                }
              },
            ]
            volumeMounts = [
              {
                name      = "ca-trust-bundle"
                mountPath = "/etc/ssl/certs/ca-certificates.crt"
                readOnly  = true
              },
            ]
          },
        ]
        volumes = [
          {
            name = "ca-trust-bundle"
            hostPath = {
              path = "/etc/ssl/certs/ca-certificates.crt"
              type = "File"
            }
          },
          {
            name = "registry-tls"
            secret = {
              secretName = module.registry-tls.name
            }
          },
        ]
      }
    })
  }
}

resource "helm_release" "arc-runner-hook-template" {
  name             = "arc-runner-hook-template"
  chart            = "../helm-wrapper"
  namespace        = "arc-runners"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      manifests = [
        module.arc-workflow-secret.manifest,
        module.registry-tls.manifest,
      ]
    }),
  ]
}

resource "helm_release" "arc-runner-set" {
  for_each = {
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
          repo     = repo
          workflow = workflow
        }
      ]
    ]) :
    "${k.workflow}-${k.repo}" => {
      repo = k.repo
      spec = "workflow-podspec-${k.workflow}.yaml"
    }
  }

  name             = each.key
  repository       = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart            = "gha-runner-scale-set"
  namespace        = "arc-runners"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  version          = "0.13.1"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      githubConfigUrl = "https://github.com/${var.github.user}/${each.value.repo}"
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
              storage = "64Gi"
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
              image = local.container_images_digest.github_actions_runner
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
                  subPath   = each.value.spec
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
  ]
  lifecycle {
    replace_triggered_by = [
      helm_release.arc,
    ]
  }
}