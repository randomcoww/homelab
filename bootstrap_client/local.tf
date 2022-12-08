locals {
  listen_ip             = split("/", var.host_ip)[0]
  matchbox_endpoint     = "http://${local.listen_ip}:${local.ports.matchbox}"
  matchbox_api_endpoint = "127.0.0.1:${local.ports.matchbox_api}"
  image_store_endpoint  = "http://${local.listen_ip}:${local.ports.matchbox}/assets"
}