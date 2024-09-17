locals {
  s3_resources = {
    # type = map(object({
    #   bucket = string
    #   path   = string
    # }))
    for name, res in {
      etcd = {
        bucket = "randomcoww-etcd-2"
        path   = "snapshot"
      }
      vaultwarden = {
        bucket = "randomcoww-vaultwarden-2"
        path   = "litestream"
      }
      documents = {
        bucket = "randomcoww-backup-2"
        path   = "documents"
      }
    } :
    name => merge(res, {
      resource = join("/", concat([res.bucket], compact(split("/", res.path))))
    })
  }

  ssm_resources = {
    tailscale = {
      resource = "tailscale-secret"
    }
  }

  cloudflare_tunnels = {
    # type = map(object({
    #   zone              = string
    #   path              = string
    #   country_whitelist = list(string)
    #   service           = string
    # }))
    external = {
      zone = local.domains.public
      path = "/"
      country_whitelist = [
        "US", "JP",
      ]
      service = "https://${local.kubernetes_services.ingress_nginx_external.endpoint}"
    }
  }
}