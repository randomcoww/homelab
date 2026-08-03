resource "random_bytes" "apiserver_encryption_key" {
  length = 32
}

module "kubernetes-master" {
  for_each = local.members.kubernetes-master
  source   = "./modules/kubernetes-master"

  butane_version = local.butane_version
  fw_mark        = local.fw_marks.accept
  name           = "master"
  cluster_name   = local.kubernetes.cluster_name
  front_proxy_ca = {
    algorithm       = tls_private_key.kubernetes-front-proxy-ca.algorithm
    private_key_pem = tls_private_key.kubernetes-front-proxy-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.kubernetes-front-proxy-ca.cert_pem
  }
  kubernetes_ca = {
    algorithm       = tls_private_key.kubernetes-ca.algorithm
    private_key_pem = tls_private_key.kubernetes-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.kubernetes-ca.cert_pem
  }
  etcd_ca = {
    algorithm       = tls_private_key.etcd-ca.algorithm
    private_key_pem = tls_private_key.etcd-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.etcd-ca.cert_pem
  }
  service_account = {
    algorithm       = tls_private_key.service-account.algorithm
    public_key_pem  = tls_private_key.service-account.public_key_pem
    private_key_pem = tls_private_key.service-account.private_key_pem
  }
  etcd_members = {
    for host_key, host in local.members.etcd :
    host_key => host_key == each.key ? "127.0.0.1" : cidrhost(local.networks.etcd.prefix, host.netnum)
  }
  images = {
    apiserver = {
      repository = "registry.k8s.io/kube-apiserver"
      tag        = "v1.36.3@sha256:b4bc06c81fd76f81174e6c19ddacf477acdf1583e7a5846ebbd513493aef6e43" # renovate: datasource=docker depName=registry.k8s.io/kube-apiserver
    }
    controller_manager = {
      repository = "registry.k8s.io/kube-controller-manager"
      tag        = "v1.36.3@sha256:ed56454bf514916079a227f5765b64524fde52106dfcc52978b28634765b78b8" # renovate: datasource=docker depName=registry.k8s.io/kube-controller-manager
    }
    scheduler = {
      repository = "registry.k8s.io/kube-scheduler"
      tag        = "v1.36.3@sha256:128fc07d278d64c4f2cce416ed0a9f37b23a30cdde6f97873d18c9c78e259df4" # renovate: datasource=docker depName=registry.k8s.io/kube-scheduler
    }
  }
  ports = {
    apiserver          = local.host_ports.apiserver
    apiserver_backend  = local.host_ports.apiserver_backend
    controller_manager = local.host_ports.controller_manager
    scheduler          = local.host_ports.scheduler
    etcd_client        = local.host_ports.etcd_client
    etcd_metrics       = local.host_ports.etcd_metrics
    bgp                = local.host_ports.bgp
  }
  kubelet_client_user        = local.kubernetes.kubelet_client_user
  cluster_apiserver_endpoint = local.endpoints.apiserver.service_fqdn
  kubernetes_service_prefix  = local.networks.kubernetes_service.prefix
  kubernetes_pod_prefix      = local.networks.kubernetes_pod.prefix
  node_ips = compact([
    for _, network in each.value.networks :
    try(cidrhost(network.prefix, each.value.netnum), null)
  ])
  apiserver_encryption_key = random_bytes.apiserver_encryption_key.base64
  apiserver_ip             = local.endpoints.apiserver_lb.service_ip
  apiserver_label          = local.endpoints.apiserver_lb.name
  cluster_apiserver_ip     = local.endpoints.apiserver.cluster_ip
  static_pod_path          = local.kubernetes.static_pod_manifest_path
  feature_gates            = local.kubernetes.feature_gates
  bird_path                = local.bird_config_path
  bird_cache_table_name    = local.bird_cache_table_name
  haproxy_path             = local.haproxy_config_path
  bgp_prefix               = each.value.networks.node.prefix
  bgp_as                   = local.bgp.host_as
  bgp_neighbor_netnums = {
    for host_key, host in local.members.gateway :
    host_key => host.netnum if each.key != host_key
  }
}