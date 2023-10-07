data "cloudflare_zone" "zone" {
  for_each = local.cloudflare_tunnels
  name     = each.value.zone
}

resource "cloudflare_zone_settings_override" "zone" {
  for_each = local.cloudflare_tunnels
  zone_id  = data.cloudflare_zone.zone[each.key].id
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
  for_each = local.cloudflare_tunnels
  zone_id  = data.cloudflare_zone.zone[each.key].id
  name     = "Geo-block"
  kind     = "zone"
  phase    = "http_request_firewall_custom"

  rules {
    action     = "block"
    expression = "(not ip.geoip.country in {\"${join("\" \"", each.value.country_whitelist)}\"})"
    enabled    = true
  }
}

resource "random_id" "cloudflare_tunnel_secret" {
  for_each    = local.cloudflare_tunnels
  byte_length = 35
}

resource "cloudflare_tunnel" "tunnel" {
  for_each   = local.cloudflare_tunnels
  name       = each.key
  account_id = var.cloudflare_account_id
  secret     = random_id.cloudflare_tunnel_secret[each.key].b64_std
}

resource "cloudflare_tunnel_config" "tunnel" {
  for_each   = local.cloudflare_tunnels
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.tunnel[each.key].id
  config {
    ingress_rule {
      hostname = "*.${each.value.zone}"
      service  = each.value.service
      path     = each.value.path
      # need to remove default params from terrafrom
      origin_request {
        http2_origin           = true
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

resource "cloudflare_record" "record" {
  for_each = local.cloudflare_tunnels
  zone_id  = data.cloudflare_zone.zone[each.key].id
  name     = "*"
  value    = "${cloudflare_tunnel.tunnel[each.key].id}.cfargotunnel.com"
  type     = "CNAME"
  proxied  = true
}