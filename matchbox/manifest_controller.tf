##
## kube controller kickstart renderer
##
resource "matchbox_profile" "manifest_controller" {
  name           = "controller"
  generic_config = "${file("./manifest/controller.yaml.tmpl")}"
}

##
## manifest
##
resource "matchbox_group" "manifest_controller" {
  name    = "${matchbox_profile.manifest_controller.name}"
  profile = "${matchbox_profile.manifest_controller.name}"

  selector {
    manifest = "${matchbox_profile.manifest_controller.name}"
  }

  metadata {
    keepalived_image              = "${var.keepalived_image}"
    kube_apiserver_image          = "${var.kube_apiserver_image}"
    kube_controller_manager_image = "${var.kube_controller_manager_image}"
    kube_scheduler_image          = "${var.kube_scheduler_image}"
    etcd_image                    = "${var.etcd_image}"

    etcd_initial_cluster       = "${join(",", formatlist("%s=https://%s:${var.etcd_peer_port}", "${var.controller_hosts}", "${var.controller_ips}"))}"
    etcd_initial_cluster_state = "new"
    etcd_cluster_token         = "${var.etcd_cluster_token}"
    etcd_servers               = "${join(",", formatlist("https://%s:${var.etcd_client_port}", "${var.controller_ips}"))}"

    etcd_client_port      = "${var.etcd_client_port}"
    etcd_peer_port        = "${var.etcd_peer_port}"
    apiserver_secure_port = "${var.apiserver_secure_port}"
    nfs_vip               = "${var.nfs_vip}"

    cluster_ip_range = "${var.cluster_ip_range}"
    cluster_cidr     = "${var.cluster_cidr}"

    controller_vip = "${var.controller_vip}"
    store_netmask  = "${var.store_netmask}"
    store_if       = "eth0"

    kubernetes_path = "${var.kubernetes_path}"
    etcd_path       = "/var/lib/etcd"
    etcd_mount_path = "${var.base_mount_path}/etcd"
  }
}
