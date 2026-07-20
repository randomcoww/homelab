# https://tailscale.com/docs/kubernetes-operator/quickstart
resource "tailscale_acl" "cluster" {
  acl = jsonencode({
    tagOwners = {
      "tag:terraform"    = ["autogroup:member"]
      "tag:k8s-operator" = ["autogroup:admin"]
      "tag:k8s"          = ["tag:k8s-operator"]
    },
    autoApprovers = {
      services = {
        "tag:k8s" = ["tag:k8s"]
      },
    },
    acls = [
      {
        action = "accept"
        src    = ["*"]
        dst    = ["*:*"]
      },
    ],
    grants = [
      {
        src = ["*"]
        dst = ["tag:k8s-operator"]
        ip  = ["tcp:443"]
      }
    ],
    nodeAttrs = [
      {
        attr   = ["mullvad"]
        target = ["autogroup:member"]
      },
    ]
  })
}

resource "tailscale_dns_configuration" "cluster" {
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
        address            = local.services.k8s_gateway.ip
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

# operator oauth client
resource "tailscale_oauth_client" "k8s-operator" {
  description = "k8s-operator"
  scopes = [
    "devices:core",
    "auth_keys",
    "services",
  ]
  tags = ["tag:k8s-operator"]

  depends_on = [
    tailscale_acl.cluster,
  ]
}