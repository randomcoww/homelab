locals {
  matchbox_endpoint     = "http://${var.listen_ip}:${local.ports.matchbox}"
  matchbox_api_endpoint = "127.0.0.1:${local.ports.matchbox_api}"
  image_store_endpoint  = "http://${var.listen_ip}:${local.ports.matchbox}/assets"
}