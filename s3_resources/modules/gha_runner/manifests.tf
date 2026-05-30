locals {
  service_account_name = "${var.name}-scale-set-controller"
  domain_regex         = "(?<hostname>(?<subdomain>[a-z0-9-*]+)\\.(?<domain>[a-z0-9.-]+))(?::(?<port>\\d+))?"

  manifests = concat([
    # runner resources in arc-runners
    module.tls.manifest,
    module.workflow-config.manifest,

    ], [
    for _, m in concat([

      # runner in arc-runners
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
      ], [

      # runner-controller in arc-systems
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
            tag = "0.14.2" # renovate: datasource=docker depName=ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller depType=helm_regex
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
    ]) :
    yamlencode(m)
  ])
}

module "workflow-config" {
  source    = "../../../modules/configmap"
  name      = "${var.name}-workflow-template"
  namespace = var.runner_namespace
  app       = var.name
  release   = var.release
  data = {
    # ADR
    # https://github.com/actions/actions-runner-controller/discussions/3152

    # kaniko container build
    "workflow-podspec-kaniko.yaml" = yamlencode({
      spec = {
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
                    name = module.tls.name
                    key  = "ca.crt"
                  }
                }
              },
              {
                name  = "INTERNAL_REGISTRY"
                value = regex(local.domain_regex, var.registry_endpoint).port == "443" ? regex(local.domain_regex, var.registry_endpoint).hostname : var.registry_endpoint
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
                name      = "internal-tls"
                mountPath = "/kaniko/.docker/ca.crt"
                subPath   = "ca.crt"
              },
              {
                name      = "internal-tls"
                mountPath = "/kaniko/.docker/client.cert"
                subPath   = "tls.crt"
              },
              {
                name      = "internal-tls"
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
            name = "internal-tls"
            secret = {
              secretName = module.tls.name
            }
          },
        ]
      }
    })

    # cosa build
    "workflow-podspec-cosa.yaml" = yamlencode({
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
                memory          = "4Gi"
                "devic.es/kvm"  = 1
                "devic.es/fuse" = 1
              }
              limits = {
                memory          = "8Gi"
                "devic.es/kvm"  = 1
                "devic.es/fuse" = 1
              }
            }
            env = [
              {
                name = "INTERNAL_CA_CERT" # add to image for pulling rootfs and ignition
                valueFrom = {
                  secretKeyRef = {
                    name = module.tls.name
                    key  = "ca.crt"
                  }
                }
              },
              {
                name  = "RCLONE_S3_ENDPOINT"
                value = var.minio_endpoint
              },
              {
                name = "AWS_ACCESS_KEY_ID"
                valueFrom = {
                  secretKeyRef = {
                    name = module.minio-user-secret.name
                    key  = "AWS_ACCESS_KEY_ID"
                  }
                }
              },
              {
                name = "AWS_SECRET_ACCESS_KEY"
                valueFrom = {
                  secretKeyRef = {
                    name = module.minio-user-secret.name
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
                    name = module.tls.name
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
                name = "DOCKER_${upper(replace(regex(local.domain_regex, var.registry_endpoint).hostname, "/[.-]/", "_"))}_HTTPSCERTIFICATE"
                valueFrom = {
                  secretKeyRef = {
                    name = module.tls.name
                    key  = "tls.crt"
                  }
                }
              },
              {
                name = "DOCKER_${upper(replace(regex(local.domain_regex, var.registry_endpoint).hostname, "/[.-]/", "_"))}_HTTPSPRIVATEKEY"
                valueFrom = {
                  secretKeyRef = {
                    name = module.tls.name
                    key  = "tls.key"
                  }
                }
              },
              {
                name = "DOCKER_${upper(replace(regex(local.domain_regex, var.registry_endpoint).hostname, "/[.-]/", "_"))}_HTTPSCERTIFICATEAUTHORITY"
                valueFrom = {
                  secretKeyRef = {
                    name = module.tls.name
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
        ]
      }
    })
  }
}

module "minio-user-secret" {
  source  = "../../../modules/secret"
  name    = "${var.name}-minio-user-secret"
  app     = var.name
  release = "0.1.0"
  data = merge({
    AWS_ACCESS_KEY_ID     = var.minio_user.id
    AWS_SECRET_ACCESS_KEY = var.minio_user.secret
  })
}