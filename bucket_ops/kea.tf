module "kea" {
  source    = "./modules/kea"
  name      = "kea"
  namespace = "hostnet"
  images = {
    kea = {
      repository = "zot.cluster.internal/randomcoww/kea"
      tag        = "v3.3.2.1791863027@sha256:2b3994d01cda065cc69f361c8dccce348f399499b0317df22f5c5680bd8c2525" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/kea
    }
    ipxe = {
      repository = "zot.cluster.internal/randomcoww/ipxe"
      tag        = "v2.0.0.1791851253@sha256:7a99c8d65520c680bc9197d9b580c4f0e532a5f1e79f824e9f6c6bb68a6ad452" # renovate: datasource=docker depName=zot.cluster.internal/randomcoww/ipxe
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
