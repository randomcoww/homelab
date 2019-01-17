# Matchbox configs for Kubernetes cluster
module "kubernetes_cluster" {
  source = "../modules/kubernetes_cluster"

  ## user (default container linux)
  default_user      = "core"
  ssh_ca_public_key = "${tls_private_key.ssh_ca.public_key_openssh}"

  ## hosts
  controller_hosts   = ["controller-0", "controller-1", "controller-2"]
  controller_ips     = ["192.168.126.219", "192.168.126.220", "192.168.126.221"]
  controller_macs    = ["52-54-00-1a-61-0a", "52-54-00-1a-61-0b", "52-54-00-1a-61-0c"]
  controller_if      = "eth0"
  controller_netmask = "23"
  worker_hosts       = ["worker-0", "worker-1", "worker-2"]
  worker_macs        = ["52-54-00-1a-61-1a", "52-54-00-1a-61-1b", "52-54-00-1a-61-1c"]
  worker_if          = "eth0"
  worker_br_if       = "eth1"

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
  keepalived_image              = "randomcoww/keepalived:20180913.01"
  cni_plugins_image             = "randomcoww/cni_plugins:0.7.1"

  ## kubernetes
  cluster_name       = "kube-cluster"
  etcd_cluster_token = "etcd-default"

  ## ports
  apiserver_secure_port = "56443"
  matchbox_http_port    = "58080"

  ## vip
  controller_vip = "192.168.126.245"
  matchbox_vip   = "192.168.126.242"

  ## etcd backup access
  aws_region            = "us-west-2"
  aws_access_key_id     = "${var.aws_access_key_id}"
  aws_secret_access_key = "${var.aws_secret_access_key}"
  s3_backup_path        = "randomcoww-etcd-backup/test-backup"

  ## renderer provisioning access
  renderer_endpoint        = "${local.renderer_endpoint}"
  renderer_cert_pem        = "${local.renderer_cert_pem}"
  renderer_private_key_pem = "${local.renderer_private_key_pem}"
  renderer_ca_pem          = "${local.renderer_ca_pem}"
}
