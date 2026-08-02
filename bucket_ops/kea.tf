module "kea" {
  source    = "./modules/kea"
  name      = "kea"
  namespace = "netboot"
  images = {
    kea  = local.container_images_digest.kea
    ipxe = local.container_images_digest.ipxe
  }
  service_ips = [
    local.endpoints.kea_primary.cluster_ip,
    local.endpoints.kea_secondary.cluster_ip,
  ]
  ports = {
    kea_peer    = local.host_ports.kea_peer
    kea_metrics = local.host_ports.kea_metrics
    ipxe        = local.host_ports.ipxe
    ipxe_tftp   = local.host_ports.ipxe_tftp
  }
  ipxe_boot_file_name  = "ipxe.efi"
  ipxe_script_base_url = "https://${local.endpoints.minio.service_ip}:${local.service_ports.minio}/boot/ipxe-"
  networks = [
    {
      prefix = local.networks.lan.prefix
      routers = [
        local.vips.gateway.ip,
      ]
      domain_name_servers = [
        local.endpoints.k8s_gateway.service_ip,
      ]
      domain_search = [
        local.domains.kubernetes,
        local.domains.public,
      ]
      classless_static_route = [
        # allow local access to these from clients that set default route over VPN
        for _, prefix in distinct([
          local.networks.service.prefix,
        ]) :
        "${prefix} - ${local.vips.gateway.ip}"
      ]
      mtu = lookup(local.networks.lan, "mtu", 1500)
    },
  ]
  timezone = local.timezone
}

resource "minio_s3_object" "fluxcd-kea" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.kea.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "kea/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}
