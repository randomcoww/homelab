# etcd #
module "etcd-cluster" {
  source        = "./modules/etcd_cluster"
  cluster_token = local.kubernetes.cluster_name
  cluster_hosts = {
    for host_key in [
      "aio-0",
    ] :
    host_key => {
      hostname    = local.hosts[host_key].hostname
      ip          = cidrhost(local.networks.lan.prefix, local.hosts[host_key].netnum)
      client_port = local.ports.etcd_client
      peer_port   = local.ports.etcd_peer
    }
  }
  aws_region       = "us-west-2"
  s3_backup_bucket = "randomcoww-etcd-backup"
}


# kubernetes #
module "kubernetes-common" {
  source                 = "./modules/kubernetes_common"
  cluster_name           = local.kubernetes.cluster_name
  apiserver_vip          = local.networks.lan.vips.apiserver
  apiserver_port         = local.ports.apiserver
  etcd_cluster_endpoints = module.etcd-cluster.cluster_endpoints
}

module "kubernetes-admin" {
  source          = "./modules/kubernetes_admin"
  ca              = module.kubernetes-common.ca
  template_params = module.kubernetes-common.template_params
}

output "admin_kubeconfig" {
  value = nonsensitive(module.kubernetes-admin.kubeconfig)
}


# ssh #
module "ssh-common" {
  source = "./modules/ssh_common"
}

module "ssh-client" {
  source                = "./modules/ssh_client"
  key_id                = var.ssh_client.key_id
  public_key_openssh    = var.ssh_client.public_key
  early_renewal_hours   = var.ssh_client.early_renewal_hours
  validity_period_hours = var.ssh_client.validity_period_hours
  ca                    = module.ssh-common.ca
}

output "ssh_client_cert_authorized_key" {
  value = module.ssh-client.ssh_client_cert_authorized_key
}


# libvirt #
module "libvirt-common" {
  source = "./modules/libvirt_common"
}


# hostapd #
module "hostapd-common" {
  source = "./modules/hostapd_common"
  roaming_interfaces = {
    for host_key in [
      "aio-0",
    ] :
    host_key => {
      interface_name = "wlan0"
      mac            = module.ignition-systemd-networkd[host_key].hardware_interfaces.wlan0.mac
    }
  }
  ssid       = var.wifi.ssid
  passphrase = var.wifi.passphrase
}