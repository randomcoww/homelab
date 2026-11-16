module "kea" {
  source    = "./modules/kea"
  name      = "kea"
  namespace = "hostnet"
  images = {
    kea = {
      repository = "zot.cluster.internal/randomcoww/kea"
      tag        = "v3.3.3.1794865053@sha256:a98e67dfcf2659643c3e3fde84f4b236d2c7f64a095f772c2d8f355a5438cc35" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/kea
    }
    ipxe = {
      repository = "zot.cluster.internal/randomcoww/ipxe"
      tag        = "v2.0.0.1794865574@sha256:fccb6266e7c83c021ebee933e5049e49982fc23e4b4b3d824e7c6bf334229f7d" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/ipxe
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
