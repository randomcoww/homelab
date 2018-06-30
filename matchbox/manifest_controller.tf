##
## kube controller kickstart renderer
##
resource "matchbox_profile" "manifest_controller" {
  name           = "manifest_controller"
  generic_config = "${file("./manifest/controller.yaml.tmpl")}"
}

##
## kickstart
##
resource "matchbox_group" "manifest_controller" {
  name    = "manifest_controller"
  profile = "${matchbox_profile.manifest_controller.name}"

  selector {
    manifest = "controller"
  }

  metadata {
    keepalived_image              = "${var.keepalived_image}"
    kube_apiserver_image          = "${var.kube_apiserver_image}"
    kube_controller_manager_image = "${var.kube_controller_manager_image}"
    kube_scheduler_image          = "${var.kube_scheduler_image}"
    etcd_image                    = "${var.etcd_image}"

    etcd_initial_cluster       = "${var.etcd_initial_cluster}"
    etcd_initial_cluster_state = "new"
    etcd_cluster_token         = "${var.etcd_cluster_token}"

    etcd_client_port      = "52379"
    apiserver_secure_port = "56443"
    nfs_vip               = "${var.nfs_vip}"

    cluster_ip_range = "${var.cluster_ip_range}"
    cluster_cidr     = "${var.cluster_cidr}"

    controller_vip = "${var.controller_vip}"
    store_netmask  = "${var.store_netmask}"
    store_if       = "eth0"

    kubernetes_path = "${var.kubernetes_path}"
    etcd_mount_path = "${var.base_mount_path}/etcd"
  }
}
