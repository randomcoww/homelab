module "ignition-base" {
  for_each = {
    for host_key in [
      "aio-0",
      "client-0",
    ] :
    host_key => local.hosts[host_key]
  }

  source   = "./modules/base"
  hostname = each.value.hostname
  users    = [
    for user_key in each.value.users :
    local.users[user_key]
  ]
}

module "ignition-systemd-networkd" {
  for_each = {
    for host_key in [
      "aio-0",
      "client-0",
    ] :
    host_key => local.hosts[host_key]
  }

  source              = "./modules/systemd_networkd"
  host_netnum         = each.value.netnum
  hardware_interfaces = each.value.hardware_interfaces
  bridge_interfaces   = each.value.bridge_interfaces
  tap_interfaces      = each.value.tap_interfaces
  networks            = local.networks
}

module "ignition-gateway" {
  for_each = {
    for host_key in [
      "aio-0",
    ] :
    host_key => local.hosts[host_key]
  }

  source                   = "./modules/gateway"
  interfaces               = module.ignition-systemd-networkd[each.key].tap_interfaces
  container_images         = local.container_images
  host_netnum              = each.value.netnum
  vrrp_netnum              = each.value.vrrp_netnum
  internal_domain          = local.domains.internal
  internal_domain_dns_ip   = local.networks.metallb.vips.external_dns
  static_pod_manifest_path = local.kubernetes.static_pod_manifest_path
  hostname                 = each.value.hostname
  dhcp_subnet = {
    newbit = 1
    netnum = 1
  }
  kea_peers = [
    for i, host_key in [
      "aio-0",
    ] :
    {
      name   = host_key
      netnum = local.hosts[host_key].netnum
      role   = try(element(["primary", "secondary"], i), "backup")
    }
  ]
  kea_peer_port     = local.ports.kea_peer
  pxeboot_file_name = "http://${local.networks.metallb.vips.internal_pxeboot}:${local.ports.internal_pxeboot_http}/boot.ipxe"
}

module "ignition-disks" {
  for_each = {
    for host_key in [
      "aio-0",
      "client-0",
    ] :
    host_key => local.hosts[host_key]
  }

  source = "./modules/disks"
  disks  = each.value.disks
}

# masterless kubelet
module "ignition-kubelet-base" {
  for_each = {
    for host_key in [
      "aio-0",
      "client-0",
    ] :
    host_key => local.hosts[host_key]
  }

  source                   = "./modules/kubelet_base"
  node_ip                  = cidrhost(local.networks.lan.prefix, each.value.netnum)
  static_pod_manifest_path = local.kubernetes.static_pod_manifest_path
}

module "ignition-etcd" {
  for_each = module.etcd-cluster.member_template_params

  source                   = "./modules/etcd_member"
  ca                       = module.etcd-cluster.ca
  peer_ca                  = module.etcd-cluster.peer_ca
  certs                    = module.etcd-cluster.certs
  template_params          = each.value
  static_pod_manifest_path = local.kubernetes.static_pod_manifest_path
  container_images         = local.container_images
}

module "ignition-kubernetes-master" {
  for_each = {
    for host_key in [
      "aio-0",
    ] :
    host_key => local.hosts[host_key]
  }

  source                   = "./modules/kubernetes_master"
  ca                       = module.kubernetes-common.ca
  etcd_ca                  = module.etcd-cluster.ca
  certs                    = module.kubernetes-common.certs
  etcd_certs               = module.etcd-cluster.certs
  template_params          = module.kubernetes-common.template_params
  addon_manifests_path     = local.kubernetes.addon_manifests_path
  static_pod_manifest_path = local.kubernetes.static_pod_manifest_path
  container_images         = local.container_images
  ports                    = local.ports
}

module "ignition-kubernetes-worker" {
  for_each = {
    for host_key in [
      "aio-0",
      "client-0",
    ] :
    host_key => local.hosts[host_key]
  }

  source                   = "./modules/kubernetes_worker"
  ca                       = module.kubernetes-common.ca
  certs                    = module.kubernetes-common.certs
  template_params          = module.kubernetes-common.template_params
  kubelet_node_labels      = { host_key = each.key }
  container_storage_path   = each.value.container_storage_path
  static_pod_manifest_path = local.kubernetes.static_pod_manifest_path
  ports                    = local.ports
}

module "ignition-libvirt" {
  for_each = {
    for host_key in [
      "aio-0",
    ] :
    host_key => local.hosts[host_key]
  }

  source       = "./modules/libvirt"
  ca           = module.libvirt-common.ca
  certs        = module.libvirt-common.certs
  ip_addresses = [cidrhost(local.networks.lan.prefix, each.value.netnum)]
  dns_names    = [each.value.hostname]
}

module "ignition-ssh-server" {
  for_each = {
    for host_key in [
      "aio-0",
    ] :
    host_key => local.hosts[host_key]
  }

  source     = "./modules/ssh_server"
  key_id     = each.value.hostname
  user_names = [local.users.admin.name]
  valid_principals = [
    each.value.hostname,
    "127.0.0.1",
    cidrhost(local.networks.lan.prefix, each.value.netnum),
  ]
  ca = module.ssh-common.ca
}

module "ignition-hostapd" {
  for_each = module.hostapd-common.template_params

  source          = "./modules/hostapd"
  template_params = each.value
}

module "ignition-addons-parser" {
  for_each = {
    for host_key in [
      "aio-0",
    ] :
    host_key => local.hosts[host_key]
  }

  source = "./modules/addons_parser"
  manifests = merge(
    module.kubernetes-system-addons.manifests,
    module.pxeboot-addons.manifests,
    module.minio-addons.manifests,
    {
      for file_name, data in data.http.remote-kubernetes-addons :
      file_name => data.body
    },
  )
  addon_manifests_path = local.kubernetes.addon_manifests_path
}

module "ignition-desktop" {
  for_each = {
    for host_key in [
      "client-0",
    ] :
    host_key => local.hosts[host_key]
  }

  source                    = "./modules/desktop"
  ssh_ca_public_key_openssh = module.ssh-common.ca.public_key_openssh
}


# combine and render a single ignition file #
data "ct_config" "ignition" {
  for_each = {
    for host_key in keys(local.hosts) :
    host_key => flatten([
      try(module.ignition-base[host_key].ignition_snippets, []),
      try(module.ignition-systemd-networkd[host_key].ignition_snippets, []),
      try(module.ignition-gateway[host_key].ignition_snippets, []),
      try(module.ignition-disks[host_key].ignition_snippets, []),
      try(module.ignition-kubelet-base[host_key].ignition_snippets, []),
      try(module.ignition-etcd[host_key].ignition_snippets, []),
      try(module.ignition-kubernetes-master[host_key].ignition_snippets, []),
      try(module.ignition-kubernetes-worker[host_key].ignition_snippets, []),
      try(module.ignition-ssh-server[host_key].ignition_snippets, []),
      try(module.ignition-libvirt[host_key].ignition_snippets, []),
      try(module.ignition-hostapd[host_key].ignition_snippets, []),
      try(module.ignition-addons-parser[host_key].ignition_snippets, []),
      try(module.ignition-desktop[host_key].ignition_snippets, []),
    ])
  }
  content  = <<EOT
---
variant: fcos
version: 1.4.0
EOT
  strict   = true
  snippets = each.value
}

resource "local_file" "ignition" {
  for_each = local.hosts

  content  = data.ct_config.ignition[each.key].rendered
  filename = "./output/ignition/${each.key}.ign"
}