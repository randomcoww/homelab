locals {
  matchbox_ip = cidrhost(
    cidrsubnet(local.networks.lan.prefix, local.kubernetes.metallb_subnet.newbit, local.kubernetes.metallb_subnet.netnum),
    local.kubernetes.metallb_pxeboot_netnum
  )
  matchbox_http_endpoint = "http://${local.matchbox_ip}:${local.ports.internal_pxeboot_http}"
  matchbox_api_endpoint  = "${local.matchbox_ip}:${local.ports.internal_pxeboot_api}"

  image_store_ip = cidrhost(
    cidrsubnet(local.networks.lan.prefix, local.kubernetes.metallb_subnet.newbit, local.kubernetes.metallb_subnet.netnum),
    local.kubernetes.metallb_minio_netnum
  )
  image_store_endpoint  = "http://${local.image_store_ip}:${local.ports.minio}"
  image_store_base_path = "boot"
}