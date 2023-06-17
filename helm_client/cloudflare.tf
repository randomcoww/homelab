data "cloudflare_zone" "internal" {
  name = local.domains.internal
}

data "cloudflare_api_token_permission_groups" "all" {
}

resource "cloudflare_api_token" "dns_edit" {
  name = "dns_edit"

  policy {
    permission_groups = [
      data.cloudflare_api_token_permission_groups.all.zone["DNS Write"],
    ]
    resources = {
      "com.cloudflare.api.account.zone.${data.cloudflare_zone.internal.id}" = "*"
    }
  }
}

resource "random_id" "cloudflare_tunnel_secret" {
  byte_length = 35
}

resource "cloudflare_tunnel" "homelab" {
  name       = "homelab"
  account_id = var.cloudflare.account_id
  secret     = random_id.cloudflare_tunnel_secret.b64_std
}

resource "cloudflare_tunnel_config" "homelab" {
  account_id = var.cloudflare.account_id
  tunnel_id  = cloudflare_tunnel.homelab.id

  config {
    ingress_rule {
      hostname = "*.${local.domains.internal}"
      path     = ""
      service  = "https://${local.kubernetes_service_endpoints.nginx}"
      # need to remove default params from terrafrom
      origin_request {
        no_tls_verify          = true
        tls_timeout            = 0
        proxy_address          = ""
        tcp_keep_alive         = 0
        connect_timeout        = 0
        keep_alive_timeout     = 0
        keep_alive_connections = 0
      }
    }
    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_record" "homelab" {
  zone_id = data.cloudflare_zone.internal.id
  name    = "*"
  value   = "${cloudflare_tunnel.homelab.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}