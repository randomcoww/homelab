module "kube-proxy" {
  source    = "./modules/kube_proxy"
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
}

module "flannel" {
  source    = "./modules/flannel"
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
      # https://kubernetes.io/docs/reference/access-authn-authz/kubelet-tls-bootstrapping/
      # enable bootstrapping nodes to create CSR
      yamlencode({
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
      }),

      # Approve all CSRs for the group "system:bootstrappers"
      yamlencode({
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
      }),

      # Approve renewal CSRs for the group "system:nodes"
      yamlencode({
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
      }),

      # kube apiserver access to kubelet #
      # https://stackoverflow.com/questions/48118125/kubernetes-rbac-role-verbs-to-exec-to-pod
      yamlencode({
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
      }),

      yamlencode({
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
      }),
    ] }),
  ]
}

# kube-proxy

resource "helm_release" "kube-proxy" {
  chart            = "../helm-wrapper"
  name             = "kube-proxy"
  namespace        = "kube-system"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  max_history      = 2
  values = [
    yamlencode({
      manifests = module.kube-proxy.manifests
    }),
  ]
}

# CNI

resource "helm_release" "flannel" {
  chart            = "../helm-wrapper"
  name             = "flannel"
  namespace        = "kube-system"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  max_history      = 2
  values = [
    yamlencode({
      manifests = module.flannel.manifests
    }),
  ]
}

# kube-dns

resource "helm_release" "kube-dns-rbac" {
  chart            = "../helm-wrapper"
  name             = "${local.endpoints.kube_dns.name}-rbac"
  namespace        = local.endpoints.kube_dns.namespace
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  max_history      = 2
  values = [
    yamlencode({ manifests = [
      yamlencode({
        apiVersion = "rbac.authorization.k8s.io/v1"
        kind       = "ClusterRole"
        metadata = {
          name = local.endpoints.kube_dns.name
        }
        rules = [
          {
            apiGroups = [""]
            resources = ["endpoints", "services", "pods", "namespaces", "nodes"]
            verbs     = ["list", "watch", "get"]
          },
          {
            apiGroups = ["discovery.k8s.io"]
            resources = ["endpointslices"]
            verbs     = ["list", "watch"]
          },
          {
            apiGroups = ["extensions", "networking.k8s.io"]
            resources = ["ingresses"]
            verbs     = ["list", "watch", "get"]
          },
          {
            apiGroups = ["networking.istio.io"]
            resources = ["gateways"]
            verbs     = ["list", "watch", "get"]
          },
          {
            apiGroups = ["gateway.networking.k8s.io"]
            resources = ["gateways", "httproutes", "tcproutes", "udproutes"]
            verbs     = ["list", "watch", "get"]
          },
        ]
      }),
      yamlencode({
        apiVersion = "rbac.authorization.k8s.io/v1"
        kind       = "ClusterRoleBinding"
        metadata = {
          name = local.endpoints.kube_dns.name
        }
        roleRef = {
          apiGroup = "rbac.authorization.k8s.io"
          kind     = "ClusterRole"
          name     = local.endpoints.kube_dns.name
        }
        subjects = [
          {
            kind      = "ServiceAccount"
            name      = "${local.endpoints.kube_dns.name}-coredns"
            namespace = local.endpoints.kube_dns.namespace
          },
        ]
      }),
    ] }),
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
  version          = "1.45.2"
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      replicaCount = 3
      serviceType  = "LoadBalancer"
      serviceAccount = {
        create = true
      }
      rbac = {
        create = false
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
        annotations = {
          "kube-vip.io/loadbalancerIPs" = local.services.external_dns.ip
        }
        clusterIP         = local.services.cluster_dns.ip
        loadBalancerClass = "kube-vip.io/kube-vip-class"
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
            # internal service
            {
              name        = "kubernetes"
              parameters  = "${local.domains.kubernetes} in-addr.arpa ip6.arpa"
              configBlock = <<-EOF
              pods insecure
              fallthrough
              EOF
            },
            # ingress
            {
              name        = "etcd"
              parameters  = "${local.domains.public} ${local.domains.kubernetes}"
              configBlock = <<-EOF
              endpoint http://localhost:2379
              fallthrough
              EOF
            },
            {
              name = "hosts"
              configBlock = join("\n", concat(compact([
                for _, host in local.hosts :
                try("${cidrhost(host.networks.service.prefix, host.netnum)} ${host.fqdn}", "")
                ]), [
                "fallthrough"
              ]))
            }
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
            ], [
            {
              name       = "cache"
              parameters = 30
            },
            {
              name       = "prometheus"
              parameters = "0.0.0.0:${local.service_ports.metrics}"
            },
          ])
        },
      ]
      extraContainers = [
        {
          name  = "${local.endpoints.kube_dns.name}-external-dns"
          image = local.container_images_digest.external_dns
          args = [
            "--source=service",
            "--source=gateway-httproute",
            "--provider=coredns",
            "--log-level=debug",
            "--metrics-address=:7979",
          ]
          env = [
            {
              name  = "ETCD_URLS"
              value = "http://localhost:2379"
            },
          ]
          ports = [
            {
              name          = "http"
              protocol      = "TCP"
              containerPort = 7979
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
          livenessProbe = {
            httpGet = {
              path = "/healthz"
              port = "http"
            }
            initialDelaySeconds = 30
            timeoutSeconds      = 2
          }
          readinessProbe = {
            httpGet = {
              path = "/healthz"
              port = "http"
            }
          }
        },
        {
          name  = "${local.endpoints.kube_dns.name}-etcd"
          image = local.container_images_digest.etcd
          command = [
            "etcd",
            "--listen-client-urls",
            "http://$(POD_IP):2379,http://127.0.0.1:2379",
            "--advertise-client-urls",
            "http://$(POD_IP):2379,http://127.0.0.1:2379",
          ]
          env = [
            {
              name = "POD_IP"
              valueFrom = {
                fieldRef = {
                  fieldPath = "status.podIP"
                }
              }
            },
          ]
          ports = [
            {
              name          = "client"
              protocol      = "TCP"
              containerPort = 2379
            },
          ]
          resources = {
            requests = {
              memory = "32Mi"
            }
            limits = {
              memory = "32Mi"
            }
          }
          livenessProbe = {
            httpGet = {
              path = "/livez"
              port = "client"
            }
            initialDelaySeconds = 10
            timeoutSeconds      = 2
          }
          readinessProbe = {
            httpGet = {
              path = "/readyz"
              port = "client"
            }
          }
        },
      ]
    }),
  ]
}

# Kubelet CSR approver

resource "helm_release" "kubelet-csr-approver" {
  name             = "kubelet-csr-approver"
  namespace        = "kube-system"
  repository       = "https://postfinance.github.io/kubelet-csr-approver"
  chart            = "kubelet-csr-approver"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  version          = "1.2.13"
  max_history      = 2
  values = [
    yamlencode({
      global = {
        clusterDomain = local.domains.kubernetes
      }
      providerRegex       = "^k-\\d+$"
      bypassDnsResolution = true
      bypassHostnameCheck = true
      providerIpPrefixes = [
        local.networks.service.prefix,
      ]
      metrics = {
        enable = true
        port   = local.service_ports.metrics
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = tostring(local.service_ports.metrics)
        }
      }
    }),
  ]
}

# fluxCD

resource "helm_release" "flux2" {
  name             = "flux2"
  namespace        = "flux-system"
  repository       = "https://fluxcd-community.github.io/helm-charts"
  chart            = "flux2"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  version          = "2.18.2"
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
}