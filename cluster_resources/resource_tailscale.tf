resource "tailscale_acl" "cluster" {
  acl = jsonencode({
    tagOwners = {
      "tag:terraform" = [
        "autogroup:member",
      ]
    },
    acls = [
      {
        action = "accept"
        users  = ["*"]
        ports  = ["*:*"]
      },
    ],
    nodeAttrs = [
      {
        attr   = ["mullvad"]
        target = ["autogroup:member"]
      },
    ]
  })
}

resource "tailscale_dns_nameservers" "cluster" {
  nameservers = [
    local.upstream_dns.ip,
  ]
}

resource "tailscale_dns_split_nameservers" "cluster" {
  for_each = toset([
    local.domains.public,
    local.domains.kubernetes,
  ])

  domain = each.key
  nameservers = [
    local.services.external_dns.ip,
  ]
}

resource "tailscale_dns_preferences" "cluster" {
  magic_dns = true
}

resource "tailscale_dns_search_paths" "cluster" {
  search_paths = [
    local.domains.kubernetes,
    local.domains.public,
  ]
}

resource "tailscale_tailnet_key" "auth" {
  reusable            = true
  ephemeral           = false
  preauthorized       = true
  recreate_if_invalid = "always"
  expiry              = 7776000
  tags = [
    "tag:terraform",
  ]
  depends_on = [
    tailscale_acl.cluster,
  ]
}