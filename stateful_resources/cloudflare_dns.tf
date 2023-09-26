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