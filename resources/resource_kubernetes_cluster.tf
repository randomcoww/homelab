# Matchbox configs for Kubernetes cluster

locals {
  kubernetes_version        = "v1.13.2"
  kubernetes_cluster_name   = "kube-cluster"
  kubernetes_apiserver_vip  = "192.168.126.245"
  kubernetes_apiserver_port = "56443"

  etcd_backup_iam_user        = "kube-cluster-etcd"
  etcd_backup_iam_policy_name = "s3-admin"

  etcd_backup_iam_policy = {
    Version = "2012-10-17"

    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:*"
        Resource = "*"
      },
    ]
  }
}

resource "aws_iam_user" "etcd_backup" {
  name = "${local.etcd_backup_iam_user}"
}

resource "aws_iam_access_key" "etcd_backup" {
  user = "${aws_iam_user.etcd_backup.name}"
}

resource "aws_iam_user_policy" "s3_access" {
  name   = "${local.etcd_backup_iam_policy_name}"
  user   = "${aws_iam_user.etcd_backup.name}"
  policy = "${jsonencode(local.etcd_backup_iam_policy)}"
}

module "kubernetes_cluster" {
  source = "../modules/kubernetes_cluster"

  ## user (default container linux)
  default_user      = "${local.default_user}"
  ssh_ca_public_key = "${tls_private_key.ssh_ca.public_key_openssh}"

  internal_domain = "${local.internal_domain}"

  ## hosts
  controller_hosts   = ["controller-0", "controller-1", "controller-2"]
  controller_ips     = ["192.168.127.219", "192.168.127.220", "192.168.127.221"]
  controller_macs    = ["52-54-00-1a-61-0a", "52-54-00-1a-61-0b", "52-54-00-1a-61-0c"]
  controller_if      = "eth0"
  controller_netmask = "23"
  worker_hosts       = ["worker-0", "worker-1", "worker-2"]
  worker_macs        = ["52-54-00-1a-61-1a", "52-54-00-1a-61-1b", "52-54-00-1a-61-1c"]
  worker_if          = "eth0"
  worker_ll_if       = "eth1"
  mtu                = "9000"

  ## images
  container_linux_base_url      = "http://beta.release.core-os.net/amd64-usr"
  container_linux_version       = "current"
  hyperkube_image               = "gcr.io/google_containers/hyperkube:${local.kubernetes_version}"
  kube_apiserver_image          = "gcr.io/google_containers/kube-apiserver:${local.kubernetes_version}"
  kube_controller_manager_image = "gcr.io/google_containers/kube-controller-manager:${local.kubernetes_version}"
  kube_scheduler_image          = "gcr.io/google_containers/kube-scheduler:${local.kubernetes_version}"
  kube_proxy_image              = "gcr.io/google_containers/kube-proxy:${local.kubernetes_version}"
  etcd_wrapper_image            = "randomcoww/etcd-wrapper:20181227.02"
  etcd_image                    = "gcr.io/etcd-development/etcd:v3.3"
  flannel_image                 = "quay.io/coreos/flannel:v0.10.0-amd64"
  keepalived_image              = "randomcoww/keepalived:20190119.01"
  cni_plugins_image             = "randomcoww/cni_plugins:0.7.5"
  coredns_image                 = "coredns/coredns:1.3.1"
  external_dns_image            = "registry.opensource.zalan.do/teapot/external-dns:latest"

  ## kubernetes
  cluster_name       = "${local.kubernetes_cluster_name}"
  etcd_cluster_token = "etcd-default"

  ## ports
  apiserver_secure_port = "${local.kubernetes_apiserver_port}"
  matchbox_http_port    = "${local.matchbox_http_port}"

  ## vip
  controller_vip    = "${local.kubernetes_apiserver_vip}"
  matchbox_vip      = "${local.matchbox_vip}"
  internal_dns_vip  = "${local.internal_dns_vip}"
  recursive_dns_vip = "${local.recursive_dns_vip}"

  ## link local mount
  worker_ll_nfs_server = "169.254.169.254:/data/worker"
  worker_ll_nfs_mount  = "/data"

  ## etcd backup access
  aws_region            = "us-west-2"
  aws_access_key_id     = "${aws_iam_access_key.etcd_backup.id}"
  aws_secret_access_key = "${aws_iam_access_key.etcd_backup.secret}"
  s3_backup_path        = "randomcoww-etcd-backup/${local.kubernetes_cluster_name}"

  ## renderer provisioning access
  renderer_endpoint        = "${local.renderer_endpoint}"
  renderer_cert_pem        = "${local.renderer_cert_pem}"
  renderer_private_key_pem = "${local.renderer_private_key_pem}"
  renderer_ca_pem          = "${local.renderer_ca_pem}"
}

data "template_file" "kubeconfig" {
  template = "${file("./templates/kubeconfig.yaml.tmpl")}"

  vars = {
    kubernetes_cluster_name       = "${local.kubernetes_cluster_name}"
    kubernetes_ca_pem             = "${replace(base64encode(chomp(module.kubernetes_cluster.kubernetes_ca_pem)), "\n", "")}"
    kubernetes_cert_pem           = "${replace(base64encode(chomp(module.kubernetes_cluster.kubernetes_cert_pem)), "\n", "")}"
    kubernetes_private_key_pem    = "${replace(base64encode(chomp(module.kubernetes_cluster.kubernetes_private_key_pem)), "\n", "")}"
    kubernetes_apiserver_endpoint = "https://${local.kubernetes_apiserver_vip}:${local.kubernetes_apiserver_port}"
  }
}

resource "local_file" "admin_kubeconfig" {
  content  = "${data.template_file.kubeconfig.rendered}"
  filename = "./output/${local.kubernetes_cluster_name}/admin.kubeconfig"
}
