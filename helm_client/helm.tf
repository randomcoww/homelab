resource "helm_release" "cluster_services" {
  name       = "cluster-services"
  namespace  = "kube-system"
  repository = "https://randomcoww.github.io/terraform-infra/"
  chart      = "cluster-services"

  set {
    name  = "images.coredns"
    value = local.container_images.coredns
  }

  set {
    name  = "images.etcd"
    value = local.container_images.etcd
  }

  set {
    name  = "images.external_dns"
    value = local.container_images.external_dns
  }

  set {
    name  = "images.flannel_cni_plugin"
    value = local.container_images.flannel_cni_plugin
  }

  set {
    name  = "images.flannel"
    value = local.container_images.flannel
  }

  set {
    name  = "images.kapprover"
    value = local.container_images.kapprover
  }

  set {
    name  = "images.kube_proxy"
    value = local.container_images.kube_proxy
  }

  set {
    name  = "pod_network_prefix"
    value = local.networks.kubernetes_pod.prefix
  }

  set {
    name  = "service_network_apiserver_ip"
    value = local.networks.kubernetes_service.vips.apiserver
  }

  set {
    name  = "service_network_dns_ip"
    value = local.networks.kubernetes_service.vips.dns
  }

  set {
    name  = "apiserver_port"
    value = local.ports.apiserver
  }

  set {
    name  = "external_dns_ip"
    value = local.networks.metallb.vips.external_dns
  }

  set {
    name  = "forwarding_dns_ip"
    value = local.networks.lan.vips.forwarding_dns
  }

  set {
    name  = "internal_domain"
    value = local.domains.internal
  }

  set {
    name  = "cluster_domain"
    value = local.domains.kubernetes
  }

  set {
    name  = "cni_bridge_interface_name"
    value = local.kubernetes.cni_bridge_interface_name
  }
}

resource "helm_release" "nginx_ingress" {
  name = "nginx-ingress-controller"

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx-ingress-controller"
}