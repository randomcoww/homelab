locals {
  tsdb_volume_name = "tsdb-volume"
  tsdb_path        = "/etc/prometheus/data"
  store_data_path  = "/etc/thanos/data"
  store_tls_path   = "/etc/thanos/tls"

  thanos_querier_port          = 10902
  thanos_querier_frontend_port = 10904
  thanos_sidecar_port          = 10901
  thanos_store_port            = 10903

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
        address = "${m.hostname}:${local.thanos_sidecar_port}"
      }
      ], [
      for _, m in local.members :
      {
        address = "${m.hostname}:${local.thanos_store_port}"
      }
    ])
  }

  thanos_sidecar_object_config = {
    type = "S3"
    config = {
      bucket       = var.minio_bucket
      endpoint     = var.minio_endpoint
      aws_sdk_auth = true
    }
  }

  thanos_store_object_config = {
    type = "S3"
    config = {
      bucket       = var.minio_bucket
      endpoint     = var.minio_endpoint
      aws_sdk_auth = true
    }
  }
}