# https://tailscale.com/docs/kubernetes-operator/quickstart
resource "tailscale_acl" "cluster" {
  acl = jsonencode({
    tagOwners = {
      "tag:k8s-operator"      = ["autogroup:admin"]
      "tag:k8s"               = ["tag:k8s-operator"]
      "tag:k8s-subnet-router" = ["tag:k8s-operator"]
    }
    autoApprovers = {
      services = {
        "tag:k8s" = ["tag:k8s"]
      }
      routes = {
        "${cidrsubnet(local.networks.service.prefix, -1, 0)}" = ["tag:k8s", "tag:k8s-subnet-router"] # hack to use a bigger range so that service network route can be overriden for local access
      }
    }
    acls = []
    grants = [
      {
        src = ["*"]
        dst = ["tag:k8s-operator"]
        ip  = ["tcp:443"]
      },
      {
        src = ["autogroup:member"]
        dst = ["${local.networks.service.prefix}"] # limit grant to actual service network range
        ip  = ["*"]
      },
    ]
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
        address            = local.endpoints.k8s_gateway.service_ip
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

# outputs

output "tailscale_oauth_client" {
  value = {
    id  = tailscale_oauth_client.k8s-operator.id
    key = tailscale_oauth_client.k8s-operator.key
  }
  sensitive = true
}