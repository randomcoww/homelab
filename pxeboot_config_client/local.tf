locals {
  matchbox_endpoint     = "http://${local.services.matchbox.ip}:${local.ports.matchbox}"
  matchbox_api_endpoint = "${local.services.matchbox.ip}:${local.ports.matchbox_api}"
  image_store_endpoint  = "http://${local.services.minio.ip}:${local.ports.minio}/${local.minio_buckets.image_store.name}"
}