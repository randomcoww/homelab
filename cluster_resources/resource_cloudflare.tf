locals {
  cloudflare_account_id = data.cloudflare_accounts.accounts.accounts[0].id
  r2_buckets = {
    etcd = {
      bucket = "etcd-snapshot"
    }
    documents = {
      bucket = "documents"
    }
    pictures = {
      bucket = "pictures"
    }
    music = {
      bucket = "music"
    }
  }
  cloudflare_tunnels = {
    # type = map(object({
    #   zone              = string
    #   path              = string
    #   country_whitelist = list(string)
    #   service           = string
    # }))
    public = {
      zone = local.domains.public
      path = "/"
      country_whitelist = [
        "US", "JP",
      ]
      service = "https://${local.kubernetes_services.ingress_nginx_external.endpoint}"
    }
  }
}

data "cloudflare_accounts" "accounts" {
}

data "cloudflare_api_token_permission_groups" "all" {
}

# R2 buckets

resource "cloudflare_r2_bucket" "bucket" {
  for_each   = local.r2_buckets
  account_id = local.cloudflare_account_id
  name       = each.key
}

resource "cloudflare_api_token" "r2_bucket" {
  for_each = local.r2_buckets
  name     = "r2-${each.key}"
  policy {
    permission_groups = [
      data.cloudflare_api_token_permission_groups.all.r2["Workers R2 Storage Bucket Item Read"],
      data.cloudflare_api_token_permission_groups.all.r2["Workers R2 Storage Bucket Item Write"],
    ]
    resources = {
      "com.cloudflare.edge.r2.bucket.${local.cloudflare_account_id}_default_${each.key}" = "*"
    }
  }
}

# Terraform bucket access for secrets provisioning

resource "cloudflare_api_token" "backend_bucket" {
  name = "r2-${data.terraform_remote_state.sr.config.bucket}"
  policy {
    permission_groups = [
      data.cloudflare_api_token_permission_groups.all.r2["Workers R2 Storage Bucket Item Read"],
      data.cloudflare_api_token_permission_groups.all.r2["Workers R2 Storage Bucket Item Write"],
    ]
    resources = {
      "com.cloudflare.edge.r2.bucket.${local.cloudflare_account_id}_default_${data.terraform_remote_state.sr.config.bucket}" = "*"
    }
  }
}

# DNS

resource "cloudflare_api_token" "dns" {
  name = "zone-dns"
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

# Zero trust

resource "cloudflare_zero_trust_gateway_certificate" "tunnel" {
  account_id      = local.cloudflare_account_id
  activate        = true
  gateway_managed = true
}

# CF tunnel

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

resource "cloudflare_zero_trust_tunnel_cloudflared" "tunnel" {
  for_each   = local.cloudflare_tunnels
  name       = each.key
  account_id = local.cloudflare_account_id
  secret     = random_id.cloudflare_tunnel_secret[each.key].b64_std
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "tunnel" {
  for_each   = local.cloudflare_tunnels
  account_id = local.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.tunnel[each.key].id
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
  content  = "${cloudflare_zero_trust_tunnel_cloudflared.tunnel[each.key].id}.cfargotunnel.com"
  type     = "CNAME"
  proxied  = true
}