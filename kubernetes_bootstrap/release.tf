## Hack to release custom charts as local chart

locals {
  modules_enabled = [
    module.bootstrap,
    module.kube-proxy,
    module.flannel,
    module.kapprover,
    module.kube-dns,
    module.kube-vip,
  ]
}

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
  cni_bin_path              = local.kubernetes.cni_bin_path
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

resource "helm_release" "local-path-provisioner" {
  name        = "local-path-provisioner"
  namespace   = "kube-system"
  repository  = "https://charts.containeroo.ch"
  chart       = "local-path-provisioner"
  wait        = false
  version     = "0.0.32"
  max_history = 2
  values = [
    yamlencode({
      replicaCount = 2
      storageClass = {
        name         = "local-path"
        defaultClass = true
      }
      nodePathMap = [
        {
          node  = "DEFAULT_PATH_FOR_NON_LISTED_NODES"
          paths = ["${local.kubernetes.containers_path}/local_path_provisioner"]
        },
      ]
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
  ]
}

# Kube-vip

module "kube-vip" {
  source    = "./modules/kube_vip"
  name      = "kube-vip"
  namespace = "kube-system"
  release   = "0.1.0"
  images = {
    kube_vip = local.container_images.kube_vip
  }
  ports = {
    apiserver        = local.host_ports.apiserver,
    kube_vip_metrics = local.host_ports.kube_vip_metrics,
  }
  bgp_as     = local.ha.bgp_as
  bgp_peeras = local.ha.bgp_as
  bgp_neighbor_ips = [
    for _, host in local.members.gateway :
    cidrhost(local.networks.service.prefix, host.netnum)
  ]
  apiserver_ip      = local.services.apiserver.ip
  service_interface = "phy0-service"
  affinity = {
    nodeAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = {
        nodeSelectorTerms = [
          {
            matchExpressions = [
              {
                key      = "node-role.kubernetes.io/control-plane"
                operator = "Exists"
              },
            ]
          },
        ]
      }
    }
  }
}

# Kube-DNS

module "kube-dns" {
  source    = "./modules/kube_dns"
  name      = "kube-dns"
  namespace = "kube-system"
  helm_template = {
    repository = "https://coredns.github.io/helm"
    chart      = "coredns"
    version    = "1.43.0"
  }
  replicas = 3
  images = {
    etcd         = local.container_images.etcd
    external_dns = local.container_images.external_dns
  }
  ports = {
    metrics = local.service_ports.metrics
  }
  service_cluster_ip      = local.services.cluster_dns.ip
  service_ip              = local.services.external_dns.ip
  loadbalancer_class_name = "kube-vip.io/kube-vip-class"
  servers = [
    {
      zones = [
        {
          zone    = "."
          scheme  = "dns://"
          use_tcp = true
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
          fallthrough
          EOF
        },
        {
          name        = "etcd"
          parameters  = local.domains.public
          configBlock = <<-EOF
          fallthrough
          EOF
        },
        {
          name        = "k8s_external"
          parameters  = local.domains.public
          configBlock = <<-EOF
          fallthrough
          EOF
        },
        {
          name = "hosts"
          configBlock = join("\n", concat([
            for key, host in local.hosts :
            "${cidrhost(host.networks.service.prefix, host.netnum)} ${key}.${local.domains.kubernetes}"
            ], [
            "fallthrough"
          ]))
        },
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
        {
          name       = "prometheus"
          parameters = "0.0.0.0:${local.service_ports.metrics}"
        },
      ]
    },
  ]
}

# all modules

resource "helm_release" "wrapper" {
  for_each = {
    for m in local.modules_enabled :
    m.chart.name => m.chart
  }
  chart            = "../helm-wrapper"
  name             = each.key
  namespace        = each.value.namespace
  create_namespace = true
  wait             = false
  timeout          = 300
  max_history      = 2
  values = [
    yamlencode({
      manifests = values(each.value.manifests)
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
  ]
}