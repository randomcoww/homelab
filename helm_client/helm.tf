resource "helm_release" "cluster_services" {
  name       = "cluster-services"
  namespace  = "kube-system"
  repository = "https://randomcoww.github.io/terraform-infra/"
  chart      = "cluster-services"
  version    = "0.1.5"
  wait       = false
  values = [
    yamlencode({
      images = {
        coredns            = local.container_images.coredns
        etcd               = local.container_images.etcd
        external_dns       = local.container_images.external_dns
        flannel_cni_plugin = local.container_images.flannel_cni_plugin
        flannel            = local.container_images.flannel
        kapprover          = local.container_images.kapprover
        kube_proxy         = local.container_images.kube_proxy
        etcd               = local.container_images.etcd
      }
      pod_network_prefix        = local.networks.kubernetes_pod.prefix
      service_network_dns_ip    = local.networks.kubernetes_service.vips.dns
      apiserver_ip              = local.networks.lan.vips.apiserver
      apiserver_port            = local.ports.apiserver
      external_dns_ip           = local.networks.metallb.vips.external_dns
      forwarding_dns_ip         = local.networks.lan.vips.forwarding_dns
      internal_domain           = local.domains.internal
      cluster_domain            = local.domains.kubernetes
      cni_bridge_interface_name = local.kubernetes.cni_bridge_interface_name
      kube_proxy_port           = local.ports.kube_proxy
    })
  ]
}

resource "helm_release" "metlallb" {
  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  namespace        = "metallb-system"
  create_namespace = true
  values = [
    yamlencode({
      configInline = {
        address-pools = [
          {
            name     = "default"
            protocol = "layer2"
            addresses = [
              local.networks.metallb.prefix
            ]
          },
        ]
      }
    })
  ]
}

resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
}

# module "syncthing-addon" {
#   source             = "./modules/syncthing"
#   resource_name      = "syncthing"
#   resource_namespace = "default"
#   replica_count      = 2
#   sync_data_path     = "/var/pv/sync"
# }

# resource "helm_release" "syncthing" {
#   name       = "syncthing"
#   namespace  = "default"
#   repository = "https://randomcoww.github.io/terraform-infra/"
#   chart      = "syncthing"
#   values = yamlencode({
#     replica_count = 2
#     image         = local.container_images.syncthing
#     data_path     = "/var/pv/sync"
#     secret_data   = module.syncthing-addon.secret
#     config        = module.syncthing-addon.config
#   })
# }