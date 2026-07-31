module "kubernetes-worker" {
  for_each = local.members.kubernetes-worker
  source   = "./modules/kubernetes_worker"

  butane_version = local.butane_version
  fw_mark        = local.fw_marks.accept
  name           = "worker"
  cluster_name   = local.kubernetes.cluster_name
  kubernetes_ca = {
    algorithm       = tls_private_key.kubernetes-ca.algorithm
    private_key_pem = tls_private_key.kubernetes-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.kubernetes-ca.cert_pem
  }
  registry_ca = {
    algorithm       = tls_private_key.internal-ca.algorithm
    private_key_pem = tls_private_key.internal-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.internal-ca.cert_pem
  }
  host_netnum             = each.value.netnum
  cluster_domain          = local.domains.kubernetes
  apiserver_endpoint      = "https://${local.vips.apiserver.ip}:${local.host_ports.apiserver}"
  kubernetes_pod_prefix   = local.networks.kubernetes_pod.prefix
  node_prefix             = each.value.networks.service.prefix
  cluster_dns_ip          = local.endpoints.kube_dns.cluster_ip
  kubelet_root_path       = local.kubernetes.kubelet_root_path
  static_pod_path         = local.kubernetes.static_pod_manifest_path
  feature_gates           = local.kubernetes.feature_gates
  cni_bin_path            = local.kubernetes.cni_bin_path
  cni_config_path         = local.kubernetes.cni_config_path
  container_storage_path  = "${local.kubernetes.containers_path}/storage"
  graceful_shutdown_delay = 480
  ports = {
    kubelet      = local.host_ports.kubelet
    crio_metrics = local.host_ports.crio_metrics
  }
  # allow host to resolve registry by name
  internal_registries = [
    {
      prefix   = local.service_ports.registry == 443 ? local.endpoints.registry.service : "${local.endpoints.registry.service}:${local.service_ports.registry}"
      location = local.service_ports.registry == 443 ? local.endpoints.registry.service_ip : "${local.endpoints.registry.service_ip}:${local.service_ports.registry}"
    },
  ]
}