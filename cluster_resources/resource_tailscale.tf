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

resource "tailscale_dns_configuration" "sample_configuration" {
  dynamic "nameservers" {
    for_each = toset(local.upstream_dns)

    content {
      address            = nameservers.value.ip
      use_with_exit_node = true
    }
  }
  dynamic "split_dns" {
    for_each = toset([
      local.domains.public,
      local.domains.kubernetes,
    ])

    content {
      domain = split_dns.value
      nameservers {
        address            = local.services.external_dns.ip
        use_with_exit_node = true
      }
    }
  }
  search_paths = [
    local.domains.public,
    local.domains.kubernetes,
  ]
  override_local_dns = true
  magic_dns          = false
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
}