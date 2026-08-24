module "kea" {
  source    = "./modules/kea"
  name      = "kea"
  namespace = "netboot"
  images = {
    kea = {
      repository = "reg.cluster.internal/randomcoww/kea"
      tag        = "v3.3.0.1787575351@sha256:141a24a41223d827438437dead74fe5ccbdfbd938e335e3e2e02fbbfcea07bc8" # renovate: datasource=docker depName=reg.cluster.internal/randomcoww/kea
    }
    ipxe = {
      repository = "reg.cluster.internal/randomcoww/ipxe"
      tag        = "v2.0.0.1787576102@sha256:ceed93949a07d5c35bb011c70fbf79c9dff757bf02f769d47f53a1363e927a84" # renovate: datasource=docker depName=reg.cluster.internal/randomcoww/ipxe
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
  ipxe_script_base_url = "https://${local.networks.service.vips.minio}:${local.service_ports.minio}/boot/ipxe-"
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
