locals {
  cloudflare_account_id = data.cloudflare_accounts.accounts.result[0].id
  cloudflare_zone_id    = data.cloudflare_zones.zones.result[0].id
  cloudflare_zone_country_whitelist = [
    "US", "JP",
  ]

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
    #   path    = string
    #   service = string
    # }))
    public = {
      path    = "/"
      service = "https://${local.kubernetes_services.ingress_nginx_external.endpoint}"
    }
  }
}

data "cloudflare_accounts" "accounts" {
}

data "cloudflare_zones" "zones" {
  account = {
    id = local.cloudflare_account_id
  }
  name = local.domains.public
}

data "cloudflare_api_token_permission_groups_list" "r2_read" {
  scope = urlencode("com.cloudflare.edge.r2.bucket")
  name  = urlencode("Workers R2 Storage Bucket Item Read")
}

data "cloudflare_api_token_permission_groups_list" "r2_write" {
  scope = urlencode("com.cloudflare.edge.r2.bucket")
  name  = urlencode("Workers R2 Storage Bucket Item Write")
}

data "cloudflare_api_token_permission_groups_list" "zone_read" {
  scope = urlencode("com.cloudflare.api.account.zone")
  name  = urlencode("Zone Read")
}

data "cloudflare_api_token_permission_groups_list" "dns_write" {
  scope = urlencode("com.cloudflare.api.account.zone")
  name  = urlencode("DNS Write")
}

# R2 buckets

resource "cloudflare_r2_bucket" "bucket" {
  for_each   = local.r2_buckets
  account_id = local.cloudflare_account_id
  name       = each.key
}

resource "cloudflare_api_token" "r2_bucket" {
  for_each = merge(local.r2_buckets, {
    "${data.terraform_remote_state.sr.config.bucket}" = {
      bucket = data.terraform_remote_state.sr.config.bucket
    }
  })
  name = "r2-${each.key}"
  policies = [
    {
      effect = "allow"
      permission_groups = [
        {
          id = data.cloudflare_api_token_permission_groups_list.r2_read.result[0].id
        },
        {
          id = data.cloudflare_api_token_permission_groups_list.r2_write.result[0].id
        },
      ]
      resources = {
        "com.cloudflare.edge.r2.bucket.${local.cloudflare_account_id}_default_${each.key}" = "*"
      }
    },
  ]
}

# DNS

resource "cloudflare_api_token" "dns" {
  name = "zone-dns"
  policies = [
    {
      effect = "allow"
      permission_groups = [
        {
          id = data.cloudflare_api_token_permission_groups_list.zone_read.result[0].id
        },
        {
          id = data.cloudflare_api_token_permission_groups_list.dns_write.result[0].id
        },
      ]
      resources = {
        "com.cloudflare.api.account.zone.*" = "*"
      }
    },
  ]
}

# Zero trust

resource "cloudflare_zero_trust_gateway_certificate" "tunnel" {
  account_id           = local.cloudflare_account_id
  validity_period_days = 90
}

# CF tunnel

resource "cloudflare_zone_setting" "zone" {
  for_each = {
    always_use_https         = "on"
    tls_1_3                  = "on"
    automatic_https_rewrites = "on"
    ssl                      = "full"
    min_tls_version          = "1.3"
    opportunistic_encryption = "on"
    websockets               = "on"
  }
  zone_id    = local.cloudflare_zone_id
  setting_id = each.key
  value      = each.value
}

resource "cloudflare_ruleset" "geo_filter" {
  zone_id = local.cloudflare_zone_id
  name    = "Geo-block"
  kind    = "zone"
  phase   = "http_request_firewall_custom"
  rules = [
    {
      action     = "block"
      expression = "(not ip.geoip.country in {\"${join("\" \"", local.cloudflare_zone_country_whitelist)}\"})"
      enabled    = true
    },
  ]
}

resource "random_id" "cloudflare_tunnel_secret" {
  for_each    = local.cloudflare_tunnels
  byte_length = 35
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "tunnel" {
  for_each      = local.cloudflare_tunnels
  name          = each.key
  account_id    = local.cloudflare_account_id
  tunnel_secret = random_id.cloudflare_tunnel_secret[each.key].b64_std
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "tunnel" {
  for_each   = local.cloudflare_tunnels
  account_id = local.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.tunnel[each.key].id
  config = {
    ingress = [
      {
        hostname = "*.${local.domains.public}"
        service  = each.value.service
        path     = each.value.path
        # need to remove default params from terrafrom
        origin_request = {
          http2_origin           = true
          no_tls_verify          = true
          tls_timeout            = 0
          proxy_address          = ""
          tcp_keep_alive         = 0
          connect_timeout        = 0
          keep_alive_timeout     = 0
          keep_alive_connections = 0
        }
      },
      {
        service = "http_status:404"
      },
    ]
  }
}

resource "cloudflare_dns_record" "record" {
  for_each = local.cloudflare_tunnels
  zone_id  = local.cloudflare_zone_id
  name     = "*"
  ttl      = 1
  content  = "${cloudflare_zero_trust_tunnel_cloudflared.tunnel[each.key].id}.cfargotunnel.com"
  type     = "CNAME"
  proxied  = true
}