module "bootstrap" {
  source    = "./modules/bootstrap"
  name      = "bootstrap"
  namespace = "kube-system"
  release   = "0.1.1"

  node_bootstrap_user = local.kubernetes.node_bootstrap_user
  kubelet_client_user = local.kubernetes.kubelet_client_user
}

module "kube-proxy" {
  source    = "./modules/kube_proxy"
  name      = "kube-proxy"
  namespace = "kube-system"
  release   = "0.1.2"
  images = {
    kube_proxy = local.container_images.kube_proxy
  }
  ports = {
    kube_proxy     = local.host_ports.kube_proxy
    kube_apiserver = local.host_ports.apiserver
  }
  kubernetes_pod_prefix = local.networks.kubernetes_pod.prefix
  kube_apiserver_ip     = local.services.apiserver.ip
}

module "flannel" {
  source    = "./modules/flannel"
  name      = "flannel"
  namespace = "kube-system"
  release   = "0.1.2"
  images = {
    flannel            = local.container_images.flannel
    flannel_cni_plugin = local.container_images.flannel_cni_plugin
  }
  ports = {
    healthz = local.host_ports.flannel_healthz
  }
  kubernetes_pod_prefix     = local.networks.kubernetes_pod.prefix
  cni_bridge_interface_name = local.kubernetes.cni_bridge_interface_name
  cni_version               = "0.3.1"
}

module "kapprover" {
  source    = "./modules/kapprover"
  name      = "kapprover"
  namespace = "kube-system"
  release   = "0.1.1"
  replicas  = 2
  images = {
    kapprover = local.container_images.kapprover
  }
}

module "kube-dns" {
  source         = "./modules/kube_dns"
  name           = "kube-dns"
  namespace      = "kube-system"
  source_release = "1.29.0"
  replicas       = 3
  images = {
    etcd         = local.container_images.etcd
    external_dns = local.container_images.external_dns
  }
  service_cluster_ip = local.services.cluster_dns.ip
  service_ip         = local.services.external_dns.ip
  servers = [
    {
      zones = [
        {
          zone = "."
        },
      ]
      port = 53
      plugins = [
        {
          name = "health"
        },
        {
          name = "ready"
        },
        {
          name        = "kubernetes"
          parameters  = "${local.domains.kubernetes} in-addr.arpa ip6.arpa"
          configBlock = <<-EOF
          pods insecure
          fallthrough in-addr.arpa ip6.arpa
          EOF
        },
        {
          name        = "etcd"
          parameters  = "${local.domains.public} in-addr.arpa ip6.arpa"
          configBlock = <<-EOF
          fallthrough
          EOF
        },
        # public DNS
        {
          name        = "forward"
          parameters  = ". tls://${local.upstream_dns.ip}"
          configBlock = <<-EOF
          tls_servername ${local.upstream_dns.hostname}
          health_check 5s
          EOF
        },
        {
          name       = "cache"
          parameters = 30
        },
      ]
    },
  ]
}

module "fuse-device-plugin" {
  source    = "./modules/fuse_device_plugin"
  name      = "fuse-device-plugin"
  namespace = "kube-system"
  release   = "0.1.1"
  images = {
    fuse_device_plugin = local.container_images.fuse_device_plugin
  }
  kubelet_root_path = local.kubernetes.kubelet_root_path
}