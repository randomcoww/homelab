##
## kube controller ignition renderer
##
resource "matchbox_profile" "ignition_controller" {
  name                   = "host_controller"
  container_linux_config = "${file("${path.module}/templates/ignition/controller.ign.tmpl")}"
  kernel                 = "${var.container_linux_base_url}/${var.container_linux_version}/coreos_production_pxe.vmlinuz"

  initrd = [
    "${var.container_linux_base_url}/${var.container_linux_version}/coreos_production_pxe_image.cpio.gz",
  ]

  args = [
    "coreos.config.url=http://${var.matchbox_vip}:${var.matchbox_http_port}/ignition?mac=$${mac:hexhyp}",
    "coreos.first_boot=yes",
    "console=hvc0",
    "coreos.autologin",
  ]
}

resource "matchbox_group" "ignition_controller" {
  count = "${length(var.controller_hosts)}"

  name    = "host_${var.controller_hosts[count.index]}"
  profile = "${matchbox_profile.ignition_controller.name}"

  selector {
    mac = "${var.controller_macs[count.index]}"
  }

  metadata {
    hostname           = "${var.controller_hosts[count.index]}"
    hyperkube_image    = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${chomp(var.ssh_ca_public_key)}"
    default_user       = "${var.default_user}"
    apiserver_url      = "https://127.0.0.1:${var.apiserver_secure_port}"

    host_ip      = "${var.controller_ips[count.index]}"
    host_if      = "${var.controller_if}"
    host_netmask = "${var.controller_netmask}"

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
    s3_backup_path        = "${var.s3_backup_path}"

    cluster_ip_range = "${var.cluster_ip_range}"
    cluster_cidr     = "${var.cluster_cidr}"
    cluster_name     = "${var.cluster_name}"

    controller_vip = "${var.controller_vip}"

    kubelet_path = "${var.kubelet_path}"
    etcd_path    = "${var.etcd_path}"

    tls_ca                     = "${replace(tls_self_signed_cert.root.cert_pem, "\n", "\\n")}"
    tls_ca_key                 = "${replace(tls_private_key.root.private_key_pem, "\n", "\\n")}"
    tls_kubernetes             = "${replace(element(tls_locally_signed_cert.kubernetes.*.cert_pem, count.index), "\n", "\\n")}"
    tls_kubernetes_key         = "${replace(element(tls_private_key.kubernetes.*.private_key_pem, count.index), "\n", "\\n")}"
    tls_controller_manager     = "${replace(tls_locally_signed_cert.controller_manager.cert_pem, "\n", "\\n")}"
    tls_controller_manager_key = "${replace(tls_private_key.controller_manager.private_key_pem, "\n", "\\n")}"
    tls_scheduler              = "${replace(tls_locally_signed_cert.scheduler.cert_pem, "\n", "\\n")}"
    tls_scheduler_key          = "${replace(tls_private_key.scheduler.private_key_pem, "\n", "\\n")}"
    tls_service_account        = "${replace(tls_private_key.service_account.public_key_pem, "\n", "\\n")}"
    tls_service_account_key    = "${replace(tls_private_key.service_account.private_key_pem, "\n", "\\n")}"
  }
}
