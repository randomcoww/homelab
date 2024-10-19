## Hack to release custom charts as local chart

locals {
  modules_enabled = [
    module.bootstrap,
    module.apiserver_service,
    module.kube-proxy,
    module.flannel,
    module.kapprover,
    module.kube-dns,
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

module "apiserver_service" {
  source = "./modules/apiserver_service"

  name       = local.kubernetes_services.apiserver_external.name
  namespace  = local.kubernetes_services.apiserver_external.namespace
  release    = "0.1.0"
  service_ip = local.services.service_apiserver.ip
  ports = {
    apiserver = local.host_ports.apiserver_backend
  }
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
  source_release = "1.32.0"
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

# local-storage storage class #

resource "helm_release" "local-path-provisioner" {
  name        = "local-path-provisioner"
  namespace   = "kube-system"
  repository  = "https://charts.containeroo.ch"
  chart       = "local-path-provisioner"
  wait        = false
  version     = "0.0.28"
  max_history = 2
  values = [
    yamlencode({
      replicaCount = 2
      storageClass = {
        name = "local-path"
      }
      nodePathMap = [
        {
          node  = "DEFAULT_PATH_FOR_NON_LISTED_NODES"
          paths = ["${local.mounts.containers_path}/local_path_provisioner"]
        },
      ]
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
  ]
}

# minio #

resource "helm_release" "minio" {
  name             = local.kubernetes_services.minio.name
  namespace        = local.kubernetes_services.minio.namespace
  repository       = "https://charts.min.io/"
  chart            = "minio"
  create_namespace = true
  wait             = true
  timeout          = 600
  version          = "5.2.0"
  max_history      = 2
  values = [
    yamlencode({
      clusterDomain = local.domains.kubernetes
      mode          = "distributed"
      rootUser      = data.terraform_remote_state.sr.outputs.minio.access_key_id
      rootPassword  = data.terraform_remote_state.sr.outputs.minio.secret_access_key
      persistence = {
        storageClass = "local-path"
      }
      drivesPerNode = 1
      replicas      = 4
      resources = {
        requests = {
          memory = "16Gi"
        }
      }
      service = {
        type      = "ClusterIP"
        port      = local.service_ports.minio
        clusterIP = local.services.cluster_minio.ip,
        externalIPs = [
          local.services.minio.ip,
        ]
      }
      ingress = {
        enabled = false
      }
      environment = {
        MINIO_API_REQUESTS_DEADLINE  = "2m"
        MINIO_STORAGE_CLASS_STANDARD = "EC:2"
        MINIO_STORAGE_CLASS_RRS      = "EC:2"
      }
      buckets        = []
      users          = []
      policies       = []
      customCommands = []
      svcaccts       = []
      affinity = {
        podAntiAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = [
            {
              labelSelector = {
                matchExpressions = [
                  {
                    key      = "app"
                    operator = "In"
                    values = [
                      "minio",
                    ]
                  },
                ]
              }
              topologyKey = "kubernetes.io/hostname"
            },
          ]
        }
      }
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
  ]
}