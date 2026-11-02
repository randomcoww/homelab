module "kea" {
  source    = "./modules/kea"
  name      = "kea"
  namespace = "hostnet"
  images = {
    kea = {
      repository = "zot.cluster.internal/randomcoww/kea"
      tag        = "v3.3.3.1793654592@sha256:aab6fad348761cc3818ece5a10fbcd59b72467bf8ad504927d7c2c67a50d87d6" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/kea
    }
    ipxe = {
      repository = "zot.cluster.internal/randomcoww/ipxe"
      tag        = "v2.0.0.1793655038@sha256:81f18545d1390e11716710d0771caad3ff19a539b822860c42b30a7f53238ede" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/ipxe
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
