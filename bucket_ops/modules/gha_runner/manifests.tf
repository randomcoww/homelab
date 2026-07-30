locals {
  service_account_name = "${var.name}-scale-set-controller"
  domain_regex         = "(?<hostname>(?<subdomain>[a-z0-9-*]+)\\.(?<domain>[a-z0-9.-]+))(?::(?<port>\\d+))?"

  kaniko_worker = {
    spec = {
      resources = {
        requests = {
          memory = "2Gi"
        }
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
                  name = "${var.name}-client-tls"
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
              name      = "internal-client-tls"
              mountPath = "/kaniko/.docker/ca.crt"
              subPath   = "ca.crt"
            },
            {
              name      = "internal-client-tls"
              mountPath = "/kaniko/.docker/client.cert"
              subPath   = "tls.crt"
            },
            {
              name      = "internal-client-tls"
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
          name = "internal-client-tls"
          secret = {
            secretName = "${var.name}-client-tls"
          }
        },
      ]
    }
  }

  cosa_worker = {
    spec = {
      resources = {
        requests = {
          memory = "4Gi"
        }
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
              "devic.es/kvm"  = 1
              "devic.es/fuse" = 1
            }
            limits = {
              "devic.es/kvm"  = 1
              "devic.es/fuse" = 1
            }
          }
          envFrom = [
            {
              secretRef = {
                name = module.user-secret.name
              }
            },
          ]
          env = [
            {
              name = "INTERNAL_CA_CERT" # add to image for pulling rootfs and ignition
              valueFrom = {
                secretKeyRef = {
                  name = "${var.name}-client-tls"
                  key  = "ca.crt"
                }
              }
            },
            {
              name  = "RCLONE_S3_ENDPOINT"
              value = var.minio_endpoint
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
  }

  renovate_worker = {
    spec = {
      resources = {
        requests = {
          memory = "2Gi"
        }
      }
      containers = [
        {
          name = "$job"
          env = [
            {
              name = "RENOVATE_TOKEN"
              valueFrom = {
                secretKeyRef = {
                  name = module.user-secret.name
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
                  name = "${var.name}-client-tls"
                  key  = "tls.crt"
                }
              }
            },
            {
              name = "DOCKER_${upper(replace(regex(local.domain_regex, var.registry_endpoint).hostname, "/[.-]/", "_"))}_HTTPSPRIVATEKEY"
              valueFrom = {
                secretKeyRef = {
                  name = "${var.name}-client-tls"
                  key  = "tls.key"
                }
              }
            },
            {
              name = "DOCKER_${upper(replace(regex(local.domain_regex, var.registry_endpoint).hostname, "/[.-]/", "_"))}_HTTPSCERTIFICATEAUTHORITY"
              valueFrom = {
                secretKeyRef = {
                  name = "${var.name}-client-tls"
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
  }
}

module "workflow-config" {
  source    = "../../../modules/configmap"
  name      = "${var.name}-workflow-template"
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    # ADR
    # https://github.com/actions/actions-runner-controller/discussions/3152

    # kaniko container build
    "workflow-podspec-kaniko.yaml" = yamlencode(local.kaniko_worker)
    "workflow-podspec-kaniko-high-memory.yaml" = yamlencode(merge(local.kaniko_worker, {
      resources = {
        requests = {
          memory = "8Gi"
        }
      }
    }))

    # cosa build
    "workflow-podspec-cosa.yaml" = yamlencode(local.cosa_worker)

    # renovate
    "workflow-podspec-renovate.yaml" = yamlencode(local.renovate_worker)
  }
}

module "user-secret" {
  source    = "../../../modules/secret"
  name      = "${var.name}-user-secret"
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = merge({
    AWS_ACCESS_KEY_ID     = var.minio_user.id
    AWS_SECRET_ACCESS_KEY = var.minio_user.secret
    RENOVATE_TOKEN        = var.github_credentials.token # GITHUB_TOKEN cannot provide all permissions needed for renovate
  })
}