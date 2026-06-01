resource "kubernetes_labels" "labels" {
  for_each = {
    for host_key, host in local.members.kubernetes-worker :
    host_key => lookup(host, "kubernetes_node_labels", {})
  }
  api_version = "v1"
  kind        = "Node"
  metadata {
    name = each.key
  }
  labels = each.value
  force  = true
}

# Bootstrap roles

resource "helm_release" "bootstrap" {
  chart            = "../helm-wrapper"
  name             = "bootstrap"
  namespace        = "kube-system"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  max_history      = 2
  values = [
    yamlencode({ manifests = [
      for _, m in [
        # https://kubernetes.io/docs/reference/access-authn-authz/kubelet-tls-bootstrapping/
        # enable bootstrapping nodes to create CSR
        {
          apiVersion = "rbac.authorization.k8s.io/v1"
          kind       = "ClusterRoleBinding"
          metadata = {
            name = "create-csrs-for-bootstrapping"
          }
          roleRef = {
            apiGroup = "rbac.authorization.k8s.io"
            kind     = "ClusterRole"
            name     = "system:node-bootstrapper"
          }
          subjects = [
            {
              apiGroup = "rbac.authorization.k8s.io"
              kind     = "Group"
              name     = "system:bootstrappers"
            },
          ]
        },

        # Approve all CSRs for the group "system:bootstrappers"
        {
          apiVersion = "rbac.authorization.k8s.io/v1"
          kind       = "ClusterRoleBinding"
          metadata = {
            name = "auto-approve-csrs-for-group"
          }
          roleRef = {
            apiGroup = "rbac.authorization.k8s.io"
            kind     = "ClusterRole"
            name     = "system:certificates.k8s.io:certificatesigningrequests:nodeclient"
          }
          subjects = [
            {
              apiGroup = "rbac.authorization.k8s.io"
              kind     = "Group"
              name     = "system:bootstrappers"
            },
          ]
        },

        # Approve renewal CSRs for the group "system:nodes"
        {
          apiVersion = "rbac.authorization.k8s.io/v1"
          kind       = "ClusterRoleBinding"
          metadata = {
            name = "auto-approve-renewals-for-nodes"
          }
          roleRef = {
            apiGroup = "rbac.authorization.k8s.io"
            kind     = "ClusterRole"
            name     = "system:certificates.k8s.io:certificatesigningrequests:selfnodeclient"
          }
          subjects = [
            {
              apiGroup = "rbac.authorization.k8s.io"
              kind     = "Group"
              name     = "system:nodes"
            },
          ]
        },

        # kube apiserver access to kubelet #
        # https://stackoverflow.com/questions/48118125/kubernetes-rbac-role-verbs-to-exec-to-pod
        {
          apiVersion = "rbac.authorization.k8s.io/v1"
          kind       = "ClusterRole"
          metadata = {
            name = "system:kube-apiserver-to-kubelet"
            annotations = {
              "rbac.authorization.kubernetes.io/autoupdate" = "true"
            }
            labels = {
              "kubernetes.io/bootstrapping" = "rbac-defaults"
            }
          }
          rules = [
            {
              apiGroups = [""]
              resources = ["nodes/proxy", "nodes/stats", "nodes/log", "nodes/spec", "nodes/metrics"]
              verbs     = ["*"]
            },
            {
              apiGroups = [""]
              resources = ["pods", "pods/log"]
              verbs     = ["get", "list"]
            },
            {
              apiGroups = [""]
              resources = ["pods/exec"]
              verbs     = ["create"]
            },
          ]
        },
        {
          apiVersion = "rbac.authorization.k8s.io/v1"
          kind       = "ClusterRoleBinding"
          metadata = {
            name = "system:kube-apiserver"
          }
          roleRef = {
            apiGroup = "rbac.authorization.k8s.io"
            kind     = "ClusterRole"
            name     = "system:kube-apiserver-to-kubelet"
          }
          subjects = [
            {
              apiGroup = "rbac.authorization.k8s.io"
              kind     = "User"
              name     = local.kubernetes.kubelet_client_user
            },
          ]
        },
      ] :
      yamlencode(m)
    ] }),
  ]
  depends_on = [
    kubernetes_labels.labels,
  ]
}

module "kube-proxy" {
  source    = "./modules/kube_proxy_release"
  name      = "kube-proxy"
  namespace = "kube-system"
  images = {
    kube_proxy = local.container_images_digest.kube_proxy
  }
  ports = {
    kube_proxy         = local.host_ports.kube_proxy
    kube_proxy_metrics = local.host_ports.kube_proxy_metrics
    kube_apiserver     = local.host_ports.apiserver
  }
  kubernetes_pod_prefix = local.networks.kubernetes_pod.prefix
  kube_apiserver_ip     = local.services.apiserver.ip

  depends_on = [
    kubernetes_labels.labels,
  ]
}

# CNI

module "flannel" {
  source    = "./modules/flannel_release"
  name      = "flannel"
  namespace = "kube-system"
  images = {
    flannel            = local.container_images_digest.flannel
    flannel_cni_plugin = local.container_images_digest.flannel_cni_plugin
  }
  ports = {
    healthz = local.host_ports.flannel_healthz
  }
  kubernetes_pod_prefix     = local.networks.kubernetes_pod.prefix
  cni_bridge_interface_name = local.kubernetes.cni_bridge_interface_name
  cni_version               = "0.3.1"
  cni_bin_path              = local.kubernetes.cni_bin_path
  cni_config_path           = local.kubernetes.cni_config_path

  depends_on = [
    kubernetes_labels.labels,
  ]
}

resource "helm_release" "kube-dns" {
  name             = local.endpoints.kube_dns.name
  namespace        = local.endpoints.kube_dns.namespace
  repository       = "https://coredns.github.io/helm"
  chart            = "coredns"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  version          = "1.46.0"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      replicaCount = 3
      serviceType  = "ClusterIP"
      serviceAccount = {
        create = true
      }
      rbac = {
        create = true
      }
      prometheus = {
        service = {
          enabled = true
          annotations = {
            "prometheus.io/scrape" = "true"
            "prometheus.io/port"   = tostring(local.service_ports.metrics)
          }
        }
      }
      service = {
        clusterIP = local.services.cluster_dns.ip
      }
      customLabels = {
        app = local.endpoints.kube_dns.name
      }
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
                      local.endpoints.kube_dns.name,
                    ]
                  },
                ]
              }
              topologyKey = "kubernetes.io/hostname"
            },
          ]
        }
      }
      priorityClassName = "system-cluster-critical"
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
          plugins = concat([
            {
              name = "health"
            },
            {
              name = "ready"
            },
            {
              name = "loop"
            },
            {
              name        = "log"
              configBlock = <<-EOF
              class error
              EOF
            },
            {
              name       = "prometheus"
              parameters = "0.0.0.0:${local.service_ports.metrics}"
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
              name       = "forward"
              parameters = "${local.domains.public} ${local.services.k8s_gateway.ip}"
            },
            {
              name       = "forward"
              parameters = "${local.domains.kubernetes} ${local.services.k8s_gateway.ip}"
            },
            ], [
            for tlshostname, ips in merge({
              for _, d in local.upstream_dns :
              d.hostname => d.ip...
            }) :
            {
              name = "forward"
              parameters = ". ${join(" ", [
                for _, ip in ips :
                "tls://${ip}"
              ])}"
              configBlock = <<-EOF
              tls_servername ${tlshostname}
              health_check 5s
              EOF
            }
          ])
        },
      ]
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
  ]
}

# LoadBalancer

module "kube-vip" {
  source    = "./modules/kube_vip_release"
  name      = "kube-vip"
  namespace = "kube-system"
  images = {
    kube_vip = local.container_images_digest.kube_vip
  }
  ports = {
    apiserver        = local.host_ports.apiserver,
    kube_vip_metrics = local.host_ports.kube_vip_metrics,
    kube_vip_health  = local.host_ports.kube_vip_health,
  }
  bgp_as     = local.ha.bgp_as
  bgp_peeras = local.ha.bgp_as
  bgp_neighbor_ips = [
    for _, host in local.members.gateway :
    cidrhost(local.networks.service.prefix, host.netnum)
  ]
  apiserver_ip      = local.services.apiserver.ip
  service_interface = "phy-service"
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
  depends_on = [
    kubernetes_labels.labels,
  ]
}

resource "helm_release" "local-path-provisioner" {
  chart            = "local-path-provisioner"
  name             = "local-path-provisioner"
  namespace        = "kube-system"
  repository       = "https://charts.containeroo.ch"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  version          = "0.0.37"
  max_history      = 2
  values = [
    yamlencode({
      replicaCount = 2
      storageClass = {
        create            = true
        name              = "local-path"
        provisionerName   = "rancher.io/local-path"
        defaultClass      = true
        defaultVolumeType = "local"
      }
      nodePathMap = [
        {
          node = "DEFAULT_PATH_FOR_NON_LISTED_NODES"
          paths = [
            "${local.kubernetes.containers_path}/local_path_provisioner",
          ]
        },
      ]
      resources = {
        requests = {
          memory = "128Mi"
        }
        limits = {
          memory = "128Mi"
        }
      }
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
  ]
}

# fluxCD

resource "helm_release" "fluxcd" {
  name             = local.endpoints.fluxcd.name
  namespace        = local.endpoints.fluxcd.namespace
  repository       = "https://fluxcd-community.github.io/helm-charts"
  chart            = "flux2"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  version          = "2.18.4"
  timeout          = local.kubernetes.helm_release_timeout
  max_history      = 2
  values = [
    yamlencode({
      clusterDomain = local.domains.kubernetes
      imageAutomationController = {
        create = false
      }
      imageReflectionController = {
        create = false
      }
      notificationController = {
        create = false
      }
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
  ]
}

# Internal S3

resource "random_password" "minio-access-key-id" {
  length  = 30
  special = false
}

resource "random_password" "minio-secret-access-key" {
  length  = 30
  special = false
}

module "minio" {
  source    = "./modules/minio_release"
  name      = local.endpoints.minio.name
  namespace = local.endpoints.minio.namespace
  timeout   = local.kubernetes.helm_release_timeout
  images = {
    nginx = local.container_images_digest.nginx
    minio = {
      repository = regex(local.container_image_regex, local.container_images.minio).depName
      tag        = regex(local.container_image_regex, local.container_images.minio).tag
    }
  }
  ports = {
    minio   = local.service_ports.minio
    metrics = local.service_ports.metrics
  }
  root_user = {
    id     = random_password.minio-access-key-id.result
    secret = random_password.minio-secret-access-key.result
  }
  cluster_domain     = local.domains.kubernetes
  ca                 = data.terraform_remote_state.host.outputs.internal_ca
  service_hostname   = local.endpoints.minio.service
  service_ip         = local.services.minio.ip
  cluster_service_ip = local.services.cluster_minio.ip

  depends_on = [
    kubernetes_labels.labels,
  ]
}