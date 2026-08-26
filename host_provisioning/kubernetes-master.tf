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
      tag        = "v1.37.0@sha256:d1045e5c6d2f016797d22143eba7502e1bb712a4681836a7c35763a9c192dd70" # renovate: datasource=docker depName=registry.k8s.io/kube-apiserver
    }
    controller-manager = {
      repository = "registry.k8s.io/kube-controller-manager"
      tag        = "v1.37.0@sha256:997c997924eb8574f63f204a0b0af133aaf33c10df84009c32d34037f4e0e077" # renovate: datasource=docker depName=registry.k8s.io/kube-controller-manager
    }
    scheduler = {
      repository = "registry.k8s.io/kube-scheduler"
      tag        = "v1.37.0@sha256:a27622f132aa09cf2461ba077894a070c0186ec607366d14e805912d4804d11f" # renovate: datasource=docker depName=registry.k8s.io/kube-scheduler
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