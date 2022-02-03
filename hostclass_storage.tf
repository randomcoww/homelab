# templates #
module "template-router-base" {
  for_each = local.router_hostclass_config.hosts

  source   = "./modules/base"
  hostname = each.value.hostname
  users    = [local.users.admin]
}

module "template-router-server" {
  for_each = local.router_hostclass_config.hosts

  source              = "./modules/server"
  networks            = local.networks
  hardware_interfaces = each.value.hardware_interfaces
  tap_interfaces      = each.value.tap_interfaces
  host_netnum         = each.value.netnum
}

module "template-router-gateway" {
  for_each = local.router_hostclass_config.hosts

  source             = "./modules/gateway"
  hostname           = each.value.hostname
  user               = local.users.admin
  interfaces         = module.template-router-server[each.key].interfaces
  container_images   = local.container_images
  dhcp_server_subnet = local.router_hostclass_config.dhcp_server_subnet
  kea_peer_port      = local.ports.kea_peer
  host_netnum        = each.value.netnum
  vrrp_netnum        = local.router_hostclass_config.vrrp_netnum
  kea_peers = [
    for host in concat(
      values(local.aio_hostclass_config.hosts),
      values(local.router_hostclass_config.hosts),
    ) :
    {
      name   = host.hostname
      role   = lookup(host, "kea_ha_role", "backup")
      netnum = host.netnum
    }
  ]
  internal_dns_ip = cidrhost(
    cidrsubnet(local.networks.lan.prefix, local.kubernetes.metallb_subnet.newbit, local.kubernetes.metallb_subnet.netnum),
    local.kubernetes.metallb_external_dns_netnum
  )
  internal_domain = local.domains.internal
  pxeboot_file_name = "http://${cidrhost(
    cidrsubnet(local.networks.lan.prefix, local.kubernetes.metallb_subnet.newbit, local.kubernetes.metallb_subnet.netnum),
    local.kubernetes.metallb_external_dns_netnum
  )}/boot.ipxe"
  static_pod_manifest_path = local.kubernetes.static_pod_manifest_path
}

module "template-router-ssh_server" {
  for_each = local.router_hostclass_config.hosts

  source     = "./modules/ssh_server"
  key_id     = each.value.hostname
  user_names = [local.users.admin.name]
  valid_principals = compact(concat([each.value.hostname, "127.0.0.1"], flatten([
    for interface in values(module.template-router-server[each.key].interfaces) :
    try(cidrhost(interface.prefix, each.value.netnum), null)
    if lookup(interface, "enable_netnum", false)
  ])))
  ssh_ca = module.ssh-server-common.ca.ssh
}

module "template-router-kubelet" {
  for_each = local.router_hostclass_config.hosts

  source                   = "./modules/kubelet"
  container_images         = local.container_images
  network_prefix           = local.networks.lan.prefix
  host_netnum              = each.value.netnum
  static_pod_manifest_path = local.kubernetes.static_pod_manifest_path
}

# combine and render a single ignition file #
data "ct_config" "router" {
  for_each = local.router_hostclass_config.hosts

  content = <<EOT
---
variant: fcos
version: 1.4.0
EOT
  strict  = true
  snippets = concat(
    module.template-router-base[each.key].ignition_snippets,
    module.template-router-server[each.key].ignition_snippets,
    module.template-router-gateway[each.key].ignition_snippets,
    module.template-router-ssh_server[each.key].ignition_snippets,
    module.template-router-kubelet[each.key].ignition_snippets,
  )
}

resource "local_file" "router" {
  for_each = local.router_hostclass_config.hosts

  content  = data.ct_config.router[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}