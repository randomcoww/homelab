locals {
  cert_manager_version = "1.21.0" # renovate: datasource=helm depName=cert-manager registryUrl=https://charts.jetstack.io
}

resource "kubernetes_labels" "labels" {
  for_each = {
    for host_key, host in local.members.kubernetes-worker :
    host_key => lookup(host, "kubernetes_node_labels", {})
    if length(lookup(host, "kubernetes_node_labels", {})) > 0
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

resource "helm_release" "local-path-provisioner" {
  chart            = "local-path-provisioner"
  name             = "local-path-provisioner"
  namespace        = "kube-system"
  repository       = "https://charts.containeroo.ch"
  create_namespace = true
  wait             = true
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

data "http" "cert-manager-crds-yaml" {
  url = "https://github.com/cert-manager/cert-manager/releases/download/v${local.cert_manager_version}/cert-manager.crds.yaml"
  request_headers = {
    Accept = "application/yaml"
  }
}

resource "helm_release" "cert-manager-crds" {
  chart            = "../helm-wrapper"
  name             = "${local.endpoints.cert_manager.name}-crds"
  namespace        = local.endpoints.cert_manager.namespace
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  max_history      = 2
  values = [
    yamlencode({
      manifests = [
        data.http.cert-manager-crds-yaml.response_body,
      ]
    }),
  ]
}

resource "helm_release" "prometheus-operator-crds" {
  name             = "${local.endpoints.prometheus.name}-crds"
  namespace        = local.endpoints.prometheus.namespace
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus-operator-crds"
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  version          = "30.0.1"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
    }),
  ]
}

# CNI

resource "helm_release" "cilium" {
  name             = local.endpoints.cilium.name
  namespace        = local.endpoints.cilium.namespace
  repository       = "https://helm.cilium.io"
  chart            = "cilium"
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  version          = "1.20.0-rc.1" # TODO: move to release version
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      routingMode          = "native"
      autoDirectNodeRoutes = true
      cni = {
        binPath  = local.kubernetes.cni_bin_path
        confPath = local.kubernetes.cni_config_path
      }
      gatewayAPI = {
        enabled    = true
        enableAlpn = true
      }
      bgpControlPlane = {
        enabled = true
      }
      hubble = {
        enabled = false
      }
      ipMasqAgent = {
        enabled = true
      }
      ipv4 = {
        enabled = true
      }
      bpf = {
        masquerade = true
      }
      ipv4NativeRoutingCIDR = local.networks.kubernetes_pod.prefix
      enableIPv4Masquerade  = true
      envoy = {
        prometheus = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
      }
      operator = {
        prometheus = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
      }
      prometheus = {
        enabled = true
        serviceMonitor = {
          enabled = true
        }
      }
      ## L2
      l2announcements = {
        enabled = true
      }
      kubeProxyReplacement                = true
      k8sServiceHost                      = local.services.apiserver.ip
      k8sServicePort                      = local.host_ports.apiserver
      kubeProxyReplacementHealthzBindAddr = "0.0.0.0:${local.host_ports.kube_proxy_healthz}"
      ##
      ipam = {
        mode = "kubernetes"
        operator = {
          clusterPoolIPv4PodCIDRList = [
            local.networks.kubernetes_pod.prefix,
          ]
        }
      }
      priorityClassName = "system-node-critical"
    })
  ]
  depends_on = [
    kubernetes_labels.labels,
    helm_release.cert-manager-crds,
  ]
}

resource "helm_release" "cilium-crs" {
  chart            = "../helm-wrapper"
  name             = "${local.endpoints.cilium.name}-crs"
  namespace        = local.endpoints.cilium.namespace
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  max_history      = 2
  values = [
    yamlencode({
      manifests = [
        for _, m in [
          {
            apiVersion = "cilium.io/v2"
            kind       = "CiliumLoadBalancerIPPool"
            metadata = {
              name : "svc-pool"
            }
            spec = {
              blocks = [
                {
                  cidr  = local.networks.service.prefix
                  start = cidrhost(cidrsubnet(local.networks.service.prefix, 1, 1), 0)
                  stop  = cidrhost(local.networks.service.prefix, -2)
                },
              ]
            }
          },
          {
            apiVersion = "gateway.networking.k8s.io/v1"
            kind       = "Gateway"
            metadata = {
              name = local.endpoints.cilium.name
              annotations = {
                "cert-manager.io/cluster-issuer" = local.kubernetes.cert_issuers.acme_prod
              }
            }
            spec = {
              gatewayClassName = "cilium"
              listeners = [
                {
                  allowedRoutes = {
                    namespaces = {
                      from = "Same"
                    }
                  }
                  name     = "web"
                  port     = 80
                  protocol = "HTTP"
                },
                {
                  allowedRoutes = {
                    namespaces = {
                      from = "All"
                    }
                  }
                  hostname = "*.${local.domains.public}"
                  name     = "websecure"
                  port     = 443
                  protocol = "HTTPS"
                  tls = {
                    mode = "Terminate"
                    certificateRefs = [
                      {
                        group = "core"
                        name  = "${local.domains.public}-tls"
                      },
                    ]
                  }
                },
              ]
            }
          },
        ] :
        yamlencode(m)
      ]
    }),
  ]
  depends_on = [
    kubernetes_labels.labels,
    helm_release.cilium,
  ]
}

resource "helm_release" "kube-dns" {
  name             = local.endpoints.kube_dns.name
  namespace        = local.endpoints.kube_dns.namespace
  repository       = "https://coredns.github.io/helm"
  chart            = "coredns"
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  version          = "1.46.2"
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
          enabled = false
        }
        monitor = {
          enabled = false # create in prometheus chart
        }
      }
      customLabels = {
        app = local.endpoints.kube_dns.name
      }
      service = {
        clusterIP = local.services.cluster_dns.ip
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
                      "kube-dns",
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
              parameters = "0.0.0.0:${local.service_ports.coredns_metrics}"
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
    helm_release.prometheus-operator-crds,
  ]
}

# LoadBalancer

resource "helm_release" "kube-vip" {
  name             = "kube-vip"
  namespace        = "kube-system"
  repository       = "https://kube-vip.github.io/helm-charts"
  chart            = "kube-vip"
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  version          = "0.9.9"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      image = {
        repository = regex(local.container_image_regex, local.container_images.kube_vip).depName
        tag        = regex(local.container_image_regex, local.container_images.kube_vip).tag
      }
      extraArgs = {
        serviceInterface  = "phy-service"
        cleanRoutingTable = true
      }
      config = {
        address = local.services.apiserver.ip
      }
      env = {
        for k, v in {
          vip_arp             = false
          port                = local.host_ports.apiserver
          prometheus_server   = ":${local.host_ports.kube_vip_metrics}"
          vip_interface       = "lo"
          dns_mode            = "first"
          cp_enable           = true
          svc_enable          = true
          lb_enable           = false
          lb_port             = local.host_ports.apiserver
          svc_leasename       = "plndr-svcs-lock"
          vip_routingtable    = false
          bgp_enable          = true
          bgp_as              = local.ha.bgp_as
          address             = local.services.apiserver.ip
          egress_withnftables = true
          bgp_peers = join(",", [
            for _, host in local.members.gateway :
            "${cidrhost(local.networks.service.prefix, host.netnum)}:${local.ha.bgp_as}::false"
          ])
        } :
        k => tostring(v)
      }
      envValueFrom = {
        vip_nodename = {
          fieldRef = {
            fieldPath = "spec.nodeName"
          }
        }
        bgp_routerid = {
          fieldRef = {
            fieldPath = "status.podIP"
          }
        }
      }
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
      resources = {
        requests = {
          memory = "128Mi"
        }
        limits = {
          memory = "128Mi"
        }
      }
      priorityClassName = "system-cluster-critical"
      podMonitor = {
        enabled = true
      }
    })
  ]

  depends_on = [
    kubernetes_labels.labels,
    helm_release.prometheus-operator-crds,
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
    minio = {
      repository = regex(local.container_image_regex, local.container_images.minio).depName
      tag        = regex(local.container_image_regex, local.container_images.minio).tag
    }
  }
  service_port = local.service_ports.minio
  root_user = {
    id     = random_password.minio-access-key-id.result
    secret = random_password.minio-secret-access-key.result
  }
  cluster_domain   = local.domains.kubernetes
  ca               = data.terraform_remote_state.host.outputs.internal_ca
  service_hostname = local.endpoints.minio.service
  service_ip       = local.services.minio.ip

  depends_on = [
    kubernetes_labels.labels,
    helm_release.local-path-provisioner,
    helm_release.prometheus-operator-crds,
    helm_release.cilium-crs,
  ]
}

# fluxCD

resource "helm_release" "fluxcd" {
  name             = local.endpoints.fluxcd.name
  namespace        = local.endpoints.fluxcd.namespace
  repository       = "https://fluxcd-community.github.io/helm-charts"
  chart            = "flux2"
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  version          = "2.19.0"
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
    helm_release.prometheus-operator-crds,
  ]
}