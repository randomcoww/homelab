locals {
  tsdb_path           = "/prometheus/data"
  store_data_path     = "/thanos/store/data"
  store_tls_path      = "/thanos/store/tls"
  compactor_data_path = "/thanos/compactor/data"
  ports = {
    thanos_querier       = 10902
    thanos_sidecar       = 10901
    thanos_sidecar_probe = 10904
    thanos_store         = 10903
    thanos_store_probe   = 10905
  }

  members = [
    for i, _ in range(var.replicas) :
    {
      name     = "${var.name}-server-${i}"
      hostname = "${var.name}-server-${i}.${var.name}-server-headless.${var.namespace}.svc.${var.cluster_domain}"
    }
  ]

  thanos_querier_sd_config = {
    endpoints = concat([
      for _, m in local.members :
      {
        address = "${m.hostname}:${local.ports.thanos_sidecar}"
      }
      ], [
      for _, m in local.members :
      {
        address = "${m.hostname}:${local.ports.thanos_store}"
      }
    ])
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
      name = "${var.name}-thanos-compactor"
      labels = {
        app     = var.name
        release = "0.1.0"
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
                    "--retention.resolution-raw=10d",
                    "--retention.resolution-5m=10d",
                    "--retention.resolution-1h=30d",
                    <<-EOF
                    --objstore.config=${yamlencode(local.thanos_object_config)}
                    EOF
                  ]
                  env = [
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