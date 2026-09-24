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
      tag        = "v1.37.1@sha256:e190f914a6cc21cab9268485d1ae7282fdeab1315ac64b668aa42d732fd1061d" # renovate: datasource=docker depName=registry.k8s.io/kube-apiserver
    }
    controller-manager = {
      repository = "registry.k8s.io/kube-controller-manager"
      tag        = "v1.37.1@sha256:d470c1b85aebb466e971c06239cc6a31a4ac337a78600cef80375a79a1be1641" # renovate: datasource=docker depName=registry.k8s.io/kube-controller-manager
    }
    scheduler = {
      repository = "registry.k8s.io/kube-scheduler"
      tag        = "v1.37.1@sha256:b6e2474a6c20309f0df1e7337364281fda95c6a0722259ba7f032a1e177d3f29" # renovate: datasource=docker depName=registry.k8s.io/kube-scheduler
    }
  }
  ports = {
    apiserver          = local.host_ports.apiserver
    apiserver_backend  = local.host_ports.apiserver_backend
    controller_manager = local.host_ports.controller-manager
    scheduler          = local.host_ports.scheduler
    etcd_client        = local.host_ports.etcd_client
    etcd_metrics       = local.host_ports.etcd_metrics
  }
  kubelet_client_user        = local.kubernetes.kubelet_client_user
  cluster_apiserver_endpoint = "kubernetes.default.svc.${local.domains.kubernetes}"
  kubernetes_service_prefix  = local.networks.kubernetes_service.prefix
  kubernetes_pod_prefix      = local.networks.kubernetes_pod.prefix
  node_ips = compact([
    for _, network in each.value.networks :
    try(cidrhost(network.prefix, each.value.netnum), null)
  ])
  apiserver_encryption_key = random_bytes.apiserver_encryption_key.base64
  apiserver_ip             = local.networks.service.vips.apiserver
  apiserver_service_label  = local.services.apiserver.name
  cluster_apiserver_ip     = local.networks.kubernetes_service.vips.apiserver
  static_pod_path          = local.kubernetes.static_pod_manifest_path
  feature_gates            = local.kubernetes.feature_gates
  bird_path                = local.bird_config_path
  bird_cache_table         = local.bird_cache_table
  haproxy_path             = local.haproxy_config_path
}