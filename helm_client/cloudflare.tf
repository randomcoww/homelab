data "cloudflare_zone" "internal" {
  name = local.domains.internal
}

resource "cloudflare_zone_settings_override" "internal" {
  zone_id = data.cloudflare_zone.internal.id
  settings {
    always_use_https         = "on"
    tls_1_3                  = "on"
    automatic_https_rewrites = "on"
    ssl                      = "full"
    min_tls_version          = "1.3"
    opportunistic_encryption = "on"
    universal_ssl            = "on"
    websockets               = "on"
  }
}

resource "cloudflare_ruleset" "geo_filter" {
  zone_id = data.cloudflare_zone.internal.id
  name    = "Block non-US IPs"
  kind    = "zone"
  phase   = "http_request_firewall_custom"

  rules {
    action     = "block"
    expression = "(ip.geoip.country ne \"US\")"
    enabled    = true
  }
}

data "cloudflare_api_token_permission_groups" "all" {
}

resource "cloudflare_api_token" "dns_edit" {
  name = "dns_edit"

  policy {
    permission_groups = [
      data.cloudflare_api_token_permission_groups.all.zone["DNS Write"],
      data.cloudflare_api_token_permission_groups.all.zone["Zone Read"],
    ]
    resources = {
      "com.cloudflare.api.account.zone.*" = "*"
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
        tls_timeout            = "0s"
        proxy_address          = ""
        tcp_keep_alive         = "0s"
        connect_timeout        = "0s"
        keep_alive_timeout     = "0s"
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