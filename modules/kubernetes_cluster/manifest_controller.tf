##
## kube controller manifest renderer
##
resource "matchbox_profile" "manifest_controller" {
  name           = "controller"
  generic_config = "${file("${path.module}/templates/manifest/controller.yaml.tmpl")}"
}

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
    etcd_wrapper_image            = "${var.etcd_wrapper_image}"
    etcd_image                    = "${var.etcd_image}"

    etcd_initial_cluster  = "${join(",", formatlist("%s=https://%s:${var.etcd_peer_port}", "${var.controller_hosts}", "${var.controller_ips}"))}"
    etcd_cluster_token    = "${var.etcd_cluster_token}"
    etcd_servers          = "${join(",", formatlist("https://%s:${var.etcd_client_port}", "${var.controller_ips}"))}"
    etcd_client_port      = "${var.etcd_client_port}"
    etcd_peer_port        = "${var.etcd_peer_port}"
    apiserver_secure_port = "${var.apiserver_secure_port}"

    aws_region            = "${var.aws_region}"
    aws_access_key_id     = "${var.aws_access_key_id}"
    aws_secret_access_key = "${var.aws_secret_access_key}"

    cluster_ip_range = "${var.cluster_ip_range}"
    cluster_cidr     = "${var.cluster_cidr}"
    cluster_name     = "${var.cluster_name}"

    controller_vip = "${var.controller_vip}"
    host_if        = "${var.controller_if}"

    kubelet_path   = "${var.kubelet_path}"
    etcd_path      = "${var.etcd_path}"
    s3_backup_path = "${var.s3_backup_path}"
  }
}
