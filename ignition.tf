# base system #

module "ignition-base" {
  for_each = local.members.base
  source   = "./modules/base"

  hostname = each.value.hostname
  users = [
    for user_key in each.value.users :
    local.users[user_key]
  ]
}

module "ignition-systemd-networkd" {
  for_each = local.members.systemd-networkd
  source   = "./modules/systemd_networkd"

  host_netnum         = each.value.netnum
  hardware_interfaces = each.value.hardware_interfaces
  bridge_interfaces   = each.value.bridge_interfaces
  tap_interfaces      = each.value.tap_interfaces
  networks            = local.networks
}

module "ignition-kubelet-base" {
  for_each = local.members.kubelet-base
  source   = "./modules/kubelet_base"

  node_ip                  = cidrhost(local.networks.lan.prefix, each.value.netnum)
  static_pod_manifest_path = local.kubernetes.static_pod_manifest_path
}

module "ignition-gateway" {
  for_each = local.members.gateway
  source   = "./modules/gateway"

  interfaces               = module.ignition-systemd-networkd[each.key].tap_interfaces
  container_images         = local.container_images
  host_netnum              = each.value.netnum
  vrrp_netnum              = each.value.vrrp_netnum
  external_ingress_ip      = local.vips.external_ingress
  internal_domain          = local.domains.internal
  internal_domain_dns_ip   = local.vips.external_dns
  static_pod_manifest_path = local.kubernetes.static_pod_manifest_path
  pod_network_prefix       = local.networks.kubernetes_pod.prefix
  kea_server_name          = each.key
  kea_peer_port            = local.ports.kea_peer
  kea_peers = [
    for i, host_key in sort(keys(local.members.gateway)) :
    {
      name   = host_key
      netnum = local.hosts[host_key].netnum
      role   = try(element(["primary", "secondary"], i), "backup")
    }
  ]
  tftp_port = local.ports.pxe_tftp
  dns_members = [
    for i, host_key in sort(keys(local.members.gateway)) :
    {
      netnum = local.hosts[host_key].netnum
    }
  ]
  coredns_port = local.ports.gateway_dns
  dhcp_subnet = {
    newbit = 1
    netnum = 1
  }
  pxeboot_file_name = "http://${local.vips.matchbox}:${local.ports.matchbox_http}/boot.ipxe"
}

module "ignition-disks" {
  for_each = local.members.disks
  source   = "./modules/disks"

  disks = each.value.disks
}

# SSH CA #

module "ssh-ca" {
  source = "./modules/ssh_ca"
}

module "ignition-ssh-server" {
  for_each = local.members.ssh-server
  source   = "./modules/ssh_server"

  key_id     = each.value.hostname
  user_names = [local.users.admin.name]
  valid_principals = [
    each.value.hostname,
    "127.0.0.1",
    cidrhost(local.networks.lan.prefix, each.value.netnum),
  ]
  ca = module.ssh-ca.ca
}

module "ssh-client" {
  source = "./modules/ssh_client"

  key_id                = var.ssh_client.key_id
  public_key_openssh    = var.ssh_client.public_key
  early_renewal_hours   = var.ssh_client.early_renewal_hours
  validity_period_hours = var.ssh_client.validity_period_hours
  ca                    = module.ssh-ca.ca
}

output "ssh_client_cert_authorized_key" {
  value = module.ssh-client.ssh_client_cert_authorized_key
}

# client desktop environment #

module "ignition-desktop" {
  for_each = local.members.desktop
  source   = "./modules/desktop"

  ssh_ca_public_key_openssh = module.ssh-ca.ca.public_key_openssh
}

# etcd #

module "etcd-cluster" {
  source = "./modules/etcd_cluster"

  cluster_token = local.kubernetes.etcd_cluster_token
  cluster_hosts = {
    for host_key, host in local.members.etcd :
    host_key => {
      hostname    = host.hostname
      client_ip   = cidrhost(local.networks.lan.prefix, host.netnum)
      peer_ip     = cidrhost(local.networks.etcd.prefix, host.netnum)
      client_port = local.ports.etcd_client
      peer_port   = local.ports.etcd_peer
    }
  }
  aws_region       = "us-west-2"
  s3_backup_bucket = "randomcoww-etcd-backup"
}

module "ignition-etcd" {
  for_each = module.etcd-cluster.members
  source   = "./modules/etcd_member"

  ca                       = module.etcd-cluster.ca
  peer_ca                  = module.etcd-cluster.peer_ca
  certs                    = module.etcd-cluster.certs
  cluster                  = module.etcd-cluster.cluster
  backup                   = module.etcd-cluster.backup
  member                   = each.value
  static_pod_manifest_path = local.kubernetes.static_pod_manifest_path
  container_images         = local.container_images
}

# kubernetes #

module "kubernetes-ca" {
  source = "./modules/kubernetes_ca"
}

module "ignition-kubernetes-master" {
  for_each = local.members.kubernetes-master
  source   = "./modules/kubernetes_master"

  cluster_name             = local.kubernetes.cluster_name
  ca                       = module.kubernetes-ca.ca
  etcd_ca                  = module.etcd-cluster.ca
  certs                    = module.kubernetes-ca.certs
  etcd_certs               = module.etcd-cluster.certs
  etcd_cluster_endpoints   = module.etcd-cluster.cluster.cluster_endpoints
  encryption_config_secret = module.kubernetes-ca.encryption_config_secret
  service_network_prefix   = local.networks.kubernetes_service.prefix
  pod_network_prefix       = local.networks.kubernetes_pod.prefix
  apiserver_cert_ips = [
    cidrhost(local.networks.lan.prefix, each.value.netnum),
    local.vips.apiserver,
    "127.0.0.1",
    local.vips.cluster_apiserver,
  ]
  apiserver_members = [
    for i, host_key in sort(keys(local.members.kubernetes-master)) :
    {
      name = host_key
      ip   = cidrhost(local.networks.lan.prefix, local.hosts[host_key].netnum),
    }
  ]
  static_pod_manifest_path = local.kubernetes.static_pod_manifest_path
  container_images         = local.container_images
  apiserver_port           = local.ports.apiserver
  apiserver_internal_port  = local.ports.apiserver_internal
  controller_manager_port  = local.ports.controller_manager
  scheduler_port           = local.ports.scheduler
}

module "ignition-kubernetes-worker" {
  for_each = local.members.kubernetes-worker
  source   = "./modules/kubernetes_worker"

  cluster_name              = local.kubernetes.cluster_name
  ca                        = module.kubernetes-ca.ca
  certs                     = module.kubernetes-ca.certs
  node_labels               = lookup(each.value, "kubernetes_worker_labels", {})
  node_taints               = lookup(each.value, "kubernetes_worker_taints", [])
  container_storage_path    = each.value.container_storage_path
  cni_bridge_interface_name = local.kubernetes.cni_bridge_interface_name
  apiserver_endpoint        = "https://${local.vips.apiserver}:${local.ports.apiserver}"
  cluster_dns_ip            = local.vips.cluster_dns
  cluster_domain            = local.domains.kubernetes
  static_pod_manifest_path  = local.kubernetes.static_pod_manifest_path
  kubelet_port              = local.ports.kubelet
}

module "kubernetes-admin" {
  source = "./modules/kubernetes_admin"

  cluster_name   = local.kubernetes.cluster_name
  ca             = module.kubernetes-ca.ca
  apiserver_ip   = local.vips.apiserver
  apiserver_port = local.ports.apiserver
}

output "admin_kubeconfig" {
  value = nonsensitive(module.kubernetes-admin.kubeconfig)
}

resource "local_file" "admin_kubeconfig" {
  content  = nonsensitive(module.kubernetes-admin.kubeconfig)
  filename = "./output/kubeconfig/${local.kubernetes.cluster_name}.kubeconfig"
}