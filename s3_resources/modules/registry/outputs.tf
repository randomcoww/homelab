output "manifests" {
  value = concat([
    for _, m in [
      {
        apiVersion = "batch/v1"
        kind       = "CronJob"
        metadata = {
          name      = "${var.name}-garbage-collect"
          namespace = var.namespace
          labels = {
            app     = var.name
            release = var.release
          }
        }
        spec = {
          schedule          = "0 * * * *"
          suspend           = false
          concurrencyPolicy = "Forbid"
          jobTemplate = {
            spec = {
              ttlSecondsAfterFinished = 1800
              template = {
                spec = {
                  restartPolicy = "Never"
                  containers = [
                    {
                      name  = var.name
                      image = var.images.registry
                      args = [
                        "garbage-collect",
                        "--delete-untagged",
                        "${local.config_path}/config.yaml",
                      ]
                      env = [
                        {
                          name = "REGISTRY_STORAGE_S3_ACCESSKEY"
                          valueFrom = {
                            secretKeyRef = {
                              name = module.minio-user-secret.name
                              key  = "AWS_ACCESS_KEY_ID"
                            }
                          }
                        },
                        {
                          name = "REGISTRY_STORAGE_S3_SECRETKEY"
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
                          name      = "config"
                          mountPath = "${local.config_path}/config.yaml"
                          subPath   = "registry-config"
                        },
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
                      name = "config"
                      secret = {
                        secretName = module.secret.name
                      }
                    },
                    {
                      name = "ca-trust-bundle"
                      hostPath = {
                        path = "/etc/ssl/certs/ca-certificates.crt"
                        type = "File"
                      }
                    },
                  ]
                  dnsConfig = {
                    options = [
                      {
                        name  = "ndots"
                        value = "2"
                      },
                    ]
                  }
                }
              }
            }
          }
        }
      },

      # server cert
      {
        apiVersion = "cert-manager.io/v1"
        kind       = "Certificate"
        metadata = {
          name      = "${var.name}-tls"
          namespace = var.namespace
        }
        spec = {
          secretName = "${var.name}-tls"
          isCA       = false
          privateKey = {
            algorithm = "ECDSA"
            size      = 521
          }
          commonName = var.name
          usages = [
            "key encipherment",
            "digital signature",
            "server auth",
          ]
          ipAddresses = [
            "127.0.0.1",
            var.service_ip,
          ]
          dnsNames = [
            var.name,
            var.service_hostname,
          ]
          issuerRef = {
            name = var.ca_issuer_name
            kind = "ClusterIssuer"
          }
        }
      },

      {
        apiVersion = "monitoring.coreos.com/v1"
        kind       = "ServiceMonitor"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          selector = {
            matchLabels = {
              app = var.name
            }
          }
          endpoints = [
            {
              path       = "/metrics"
              targetPort = var.ports.metrics
            },
          ]
        }
      },
    ] :
    yamlencode(m)
    ], [
    module.secret.manifest,
    module.deployment.manifest,
    module.minio-user-secret.manifest,
    module.service.manifest,
  ])
}