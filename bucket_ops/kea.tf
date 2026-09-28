module "kea" {
  source    = "./modules/kea"
  name      = "kea"
  namespace = "hostnet"
  images = {
    kea = {
      repository = "zot.cluster.internal/randomcoww/kea"
      tag        = "v3.3.1.1790624253@sha256:33849d4f7f84e13ed7f90ae22826fc4d9b7a5ba45a62c3f0d4e1ea9a41bb0480" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/kea
    }
    ipxe = {
      repository = "zot.cluster.internal/randomcoww/ipxe"
      tag        = "v2.0.0.1790623489@sha256:51f9fae8d07f0f702cb8603d4e8ab54408dea67527bd7bd3339775260aac73e8" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/ipxe
    }
  }
  peer_service_ips = [
    local.networks.kubernetes_service.vips.kea_primary,
    local.networks.kubernetes_service.vips.kea_secondary,
  ]
  ports = {
    kea_peer  = local.host_ports.kea_peer
    stork     = local.host_ports.kea_metrics
    ipxe      = local.host_ports.ipxe
    ipxe_tftp = local.host_ports.ipxe_tftp
  }
  ipxe_boot_file_name  = "ipxe.efi"
  ipxe_script_base_url = "https://${local.networks.service.vips.ipxe-presign}:${local.ipxe-presign_port}/boot.ipxe"
  dhcp_networks = [
    {
      config = local.networks.lan
      option_data = {
        tcode = local.timezone
        domain-name-servers = join(",", sort([
          local.networks.service.vips.k8s-gateway,
        ]))
        domain-search = join(",", sort([
          local.domains.kubernetes,
          local.domains.public,
        ]))
        classless-static-route = join(",", sort([
          for _, prefix in distinct([
            for _, network in local.networks :
            network.prefix if contains(keys(network), "prefix") # override tailscale exit node to allow local access
          ]) :
          "${prefix} - ${local.networks.lan.vips.vrrp}"
        ]))
      }
    },
  ]
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
