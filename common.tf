# etcd #
module "etcd-cluster" {
  source        = "./modules/etcd_cluster"
  cluster_token = "aio-prod-3"
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
  cluster_name           = "aio-prod-3"
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





# module "ignition-minio" {
#   for_each = {
#     for host_key in [
#       "aio-0",
#     ] :
#     host_key => local.hosts[host_key]
#   }

#   source                   = "./modules/minio"
#   minio_container_image    = local.container_images.minio
#   minio_port               = local.ports.minio
#   minio_console_port       = local.ports.minio_console
#   volume_paths             = each.value.minio_volume_paths
#   static_pod_manifest_path = local.kubernetes.static_pod_manifest_path
#   minio_credentials = {
#     access_key_id     = random_password.minio-access-key-id.result
#     secret_access_key = random_password.minio-secret-access-key.result
#   }
# }