output "manifests" {
  value = concat([
    for _, m in [
      {
        apiVersion = "batch/v1"
        kind       = "CronJob"
        metadata = {
          name = "${var.name}-garbage-collect"
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
                metadata = {
                  labels = {
                    app = var.name
                  }
                }
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
                              name = var.minio_access_secret
                              key  = "AWS_ACCESS_KEY_ID"
                            }
                          }
                        },
                        {
                          name = "REGISTRY_STORAGE_S3_SECRETKEY"
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
                      name = "registry-tls"
                      projected = {
                        sources = [
                          {
                            secret = {
                              name = module.tls.name
                              items = [
                                {
                                  key  = "ca.crt"
                                  path = "ca-cert.pem"
                                },
                              ]
                            }
                          },
                        ]
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
    ] :
    yamlencode(m)
    ], [
    module.secret.manifest,
    module.deployment.manifest,
    module.tls.manifest,
    module.service.manifest,
  ])
}