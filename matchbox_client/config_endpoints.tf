locals {
  matchbox_endpoint     = "http://${local.services.matchbox.ip}:${local.service_ports.matchbox}"
  matchbox_api_endpoint = "${local.services.matchbox_api.ip}:${local.service_ports.matchbox_api}"
  image_store_endpoint  = "http://${local.services.minio.ip}:${local.service_ports.minio}/${local.minio_data_buckets.boot.name}"
}