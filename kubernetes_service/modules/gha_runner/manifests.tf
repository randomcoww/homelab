locals {
  service_account_name = "${var.name}-scale-set-controller"
  domain_regex         = "(?<hostname>(?<subdomain>[a-z0-9-*]+)\\.(?<domain>[a-z0-9.-]+))(?::(?<port>\\d+))?"
}

module "workflow-config" {
  source  = "../../../modules/configmap"
  name    = "${var.name}-workflow-template"
  app     = var.name
  release = var.release
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
                value = regex(local.domain_regex, var.registry_endpoint).port == 443 ? regex(local.domain_regex, var.registry_endpoint).hostname : var.registry_endpoint
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
                    name = var.minio_access_secret
                    key  = "AWS_ACCESS_KEY_ID"
                  }
                }
              },
              {
                name = "AWS_SECRET_ACCESS_KEY"
                valueFrom = {
                  secretKeyRef = {
                    name = var.minio_access_secret
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