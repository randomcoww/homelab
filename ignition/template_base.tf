module "base" {
  for_each = local.members.base
  source   = "./modules/base"

  butane_version = local.butane_version
  hostname       = each.key
  hosts_entry    = "${cidrhost(each.value.networks.service.prefix, each.value.netnum)} ${each.value.fqdn} ${each.key}"
}

module "upstream-dns" {
  for_each       = local.members.upstream-dns
  source         = "./modules/upstream_dns"
  butane_version = local.butane_version
  upstream_dns   = local.upstream_dns
}

module "systemd-networkd" {
  for_each = local.members.systemd-networkd
  source   = "./modules/systemd_networkd"

  butane_version      = local.butane_version
  fw_mark             = local.fw_marks.accept
  host_netnum         = each.value.netnum
  physical_interfaces = each.value.physical_interfaces
  bridge_interfaces   = each.value.bridge_interfaces
  vlan_interfaces     = each.value.vlan_interfaces
  networks            = each.value.networks
  wlan_networks       = each.value.wlan_networks
}

module "server" {
  for_each = local.members.server
  source   = "./modules/server"

  butane_version = local.butane_version
  fw_mark        = local.fw_marks.accept
  # SSH
  user   = local.users.ssh
  key_id = each.key
  valid_principals = sort(concat([
    for _, network in each.value.networks :
    cidrhost(network.prefix, each.value.netnum)
    if lookup(network, "enable_netnum", false)
    ], [
    each.key,
    "${each.value.fqdn}",
    "127.0.0.1",
  ]))
  ssh_ca = {
    algorithm          = tls_private_key.ssh-ca.algorithm
    private_key_pem    = tls_private_key.ssh-ca.private_key_pem
    public_key_openssh = tls_private_key.ssh-ca.public_key_openssh
  }
  internal_ca = {
    cert_pem = tls_self_signed_cert.trusted-ca.cert_pem
  }
  # HA config
  keepalived_path       = local.ha.keepalived_config_path
  haproxy_path          = local.ha.haproxy_config_path
  bird_path             = local.ha.bird_config_path
  bird_cache_table_name = local.ha.bird_cache_table_name
  bgp_router_id = reverse(sort(compact([
    for _, network in each.value.networks :
    cidrhost(network.prefix, each.value.netnum)
    if lookup(network, "enable_netnum", false)
  ])))[0]
  bgp_port = local.host_ports.bgp
}