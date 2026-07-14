locals {
  store_data_path     = "/thanos/store/data"
  compactor_data_path = "/thanos/compactor/data"
  ports = {
    thanos_querier     = 10906
    thanos_sidecar     = 10901
    thanos_store       = 10903
    thanos_store_probe = 10905
    prometheus         = 9090
  }

  thanos_object_config = {
    type = "S3"
    config = {
      bucket       = var.minio_bucket
      endpoint     = var.minio_endpoint
      aws_sdk_auth = true
    }
  }

  compactor_job = {
    apiVersion = "batch/v1"
    kind       = "CronJob"
    metadata = {
      name      = "${var.name}-thanos-compactor"
      namespace = var.namespace
      labels = {
        app     = var.name
        release = "0.1.0"
      }
      annotations = {
        "checksum/minio-user-secret" = sha256(module.minio-user-secret.manifest)
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
                  name  = "thanos-compactor"
                  image = var.images.thanos
                  args = [
                    "compact",
                    "--web.disable",
                    "--data-dir=${local.compactor_data_path}",
                    "--retention.resolution-raw=40h",
                    "--retention.resolution-5m=10d", # should not be used with downsampling.disable
                    "--retention.resolution-1h=10d", # should not be used with downsampling.disable
                    "--downsampling.disable",
                    <<-EOF
                    --objstore.config=${yamlencode(local.thanos_object_config)}
                    EOF
                  ]
                  env = [
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
                      name      = "thanos-compactor-data"
                      mountPath = local.compactor_data_path
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
                  name = "thanos-compactor-data"
                  emptyDir = {
                    medium = "Memory"
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
  }
}

module "minio-user-secret" {
  source    = "../../../modules/secret"
  name      = "${var.name}-minio-user-secret"
  namespace = var.namespace
  app       = var.name
  release   = "0.1.0"
  data = merge({
    AWS_ACCESS_KEY_ID     = var.minio_user.id
    AWS_SECRET_ACCESS_KEY = var.minio_user.secret
  })
}