# Matchbox configs for Kubernetes cluster
module "kubernetes_cluster" {
  source = "./module_kubernetes_cluster"

  ## user (default container linux)
  default_user      = "core"
  ssh_ca_public_key = "${tls_private_key.ssh_ca.public_key_openssh}"

  ## hosts
  controller_hosts = ["controller-0", "controller-1", "controller-2"]
  controller_ips   = ["192.168.126.219", "192.168.126.220", "192.168.126.221"]
  controller_macs  = ["52-54-00-1a-61-0a", "52-54-00-1a-61-0b", "52-54-00-1a-61-0c"]
  controller_if    = "eth0"

  worker_hosts = ["worker-0", "worker-1"]
  worker_macs  = ["52-54-00-1a-61-1a", "52-54-00-1a-61-1b"]

  ## images
  container_linux_version       = "1828.3.0"
  hyperkube_image               = "gcr.io/google_containers/hyperkube:${local.kubernetes_version}"
  kube_apiserver_image          = "gcr.io/google_containers/kube-apiserver:${local.kubernetes_version}"
  kube_controller_manager_image = "gcr.io/google_containers/kube-controller-manager:${local.kubernetes_version}"
  kube_scheduler_image          = "gcr.io/google_containers/kube-scheduler:${local.kubernetes_version}"
  kube_proxy_image              = "gcr.io/google_containers/kube-proxy:${local.kubernetes_version}"
  etcd_image                    = "quay.io/coreos/etcd:v3.3"
  flannel_image                 = "quay.io/coreos/flannel:v0.10.0-amd64"
  keepalived_image              = "randomcoww/keepalived:20180716.01"

  ## kubernetes
  cluster_name       = "kube-cluster"
  etcd_cluster_token = "etcd-default"

  ## ports
  apiserver_secure_port = "56443"
  matchbox_http_port    = "58080"

  ## vip
  controller_vip = "192.168.126.245"
  nfs_vip        = "192.168.126.251"
  matchbox_vip   = "192.168.126.242"

  ## ip ranges
  netmask = "23"

  ## vm runs on ram, mount etcd data path from host
  etcd_mount_path = "/data/pv/etcd"

  ## renderer provisioning access
  renderer_endpoint        = "${local.renderer_endpoint}"
  renderer_cert_pem        = "${local.renderer_cert_pem}"
  renderer_private_key_pem = "${local.renderer_private_key_pem}"
  renderer_ca_pem          = "${local.renderer_ca_pem}"
}
