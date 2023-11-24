# basic system #

resource "helm_release" "cluster-services" {
  name       = "cluster-services"
  namespace  = "kube-system"
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "cluster-services"
  wait       = false
  version    = "0.2.5"
  values = [
    yamlencode({
      images = {
        flannelCNIPlugin = local.container_images.flannel_cni_plugin
        flannel          = local.container_images.flannel
        kapprover        = local.container_images.kapprover
        kubeProxy        = local.container_images.kube_proxy
      }
      ports = {
        kubeProxy = local.ports.kube_proxy
        apiServer = local.ports.apiserver
      }
      apiServerIP      = local.services.apiserver.ip
      cniInterfaceName = local.kubernetes.cni_bridge_interface_name
      podNetworkPrefix = local.networks.kubernetes_pod.prefix
      internalDomain   = local.domains.internal
    }),
  ]
}

# coredns #

resource "helm_release" "kube-dns" {
  name       = "kube-dns"
  namespace  = "kube-system"
  repository = "https://coredns.github.io/helm"
  chart      = "coredns"
  wait       = false
  version    = "1.22.0"
  values = [
    yamlencode({
      image = {
        repository = split(":", local.container_images.coredns)[0]
        tag        = split(":", local.container_images.coredns)[1]
      }
      replicaCount = 2
      serviceType  = "ClusterIP"
      serviceAccount = {
        create = false
      }
      service = {
        clusterIP = local.services.cluster_dns.ip
        externalIPs = [
          local.services.external_dns.ip,
        ]
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
              configBlock = <<EOF
pods insecure
fallthrough in-addr.arpa ip6.arpa
ttl 30
EOF
            },
            # cert-manager uses to verify resources internally
            {
              name       = "forward"
              parameters = "${local.domains.internal} dns://${local.services.cluster_external_dns.ip}"
            },
            {
              name        = "forward"
              parameters  = ". tls://${local.upstream_dns.ip}"
              configBlock = <<EOF
tls_servername ${local.upstream_dns.tls_servername}
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
    }),
  ]
}

# coredns with external-dns #

resource "helm_release" "external-dns" {
  name       = "external-dns"
  namespace  = "kube-system"
  repository = "https://randomcoww.github.io/repos/helm/"
  chart      = "external-dns"
  wait       = false
  version    = "0.1.15"
  values = [
    yamlencode({
      mode           = "DaemonSet"
      internalDomain = local.domains.internal
      images = {
        coreDNS     = local.container_images.coredns
        externalDNS = local.container_images.external_dns
        etcd        = local.container_images.etcd
      }
      serviceAccount = {
        create = true
        name   = "external-dns"
      }
      hostNetwork = {
        enabled = false
      }
      priorityClassName = "system-cluster-critical"
      dataSources = [
        "service",
        "ingress",
      ]
      service = {
        type      = "ClusterIP"
        clusterIP = local.services.cluster_external_dns.ip
      }
      coreDNSLivenessProbe = {
        httpGet = {
          path   = "/health"
          port   = 8080
          scheme = "HTTP"
        }
        initialDelaySeconds = 30
        periodSeconds       = 10
        timeoutSeconds      = 5
        failureThreshold    = 5
        successThreshold    = 1
      }
      coreDNSReadinessProbe = {
        httpGet = {
          path   = "/ready"
          port   = 8181
          scheme = "HTTP"
        }
        initialDelaySeconds = 30
        periodSeconds       = 10
        timeoutSeconds      = 5
        failureThreshold    = 5
        successThreshold    = 1
      }
      servers = [
        {
          zones = [
            {
              zone = "."
            },
          ]
          port = local.ports.gateway_dns
          plugins = [
            {
              name = "health"
            },
            {
              name = "ready"
            },
            {
              name        = "etcd"
              parameters  = "${local.domains.internal} in-addr.arpa ip6.arpa"
              configBlock = <<EOF
fallthrough
EOF
            },
            {
              name        = "forward"
              parameters  = ". tls://${local.upstream_dns.ip}"
              configBlock = <<EOF
tls_servername ${local.upstream_dns.tls_servername}
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
    }),
  ]
}

# local-storage storage class #

resource "helm_release" "local-path-provisioner" {
  name       = "local-path-provisioner"
  namespace  = "kube-system"
  repository = "https://charts.containeroo.ch"
  chart      = "local-path-provisioner"
  wait       = false
  version    = "0.0.24"
  values = [
    yamlencode({
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
}

# fuse device plugin #

resource "helm_release" "fuse-device-plugin" {
  name             = "fuse-device-plugin"
  repository       = "https://randomcoww.github.io/repos/helm/"
  chart            = "helm-wrapper"
  namespace        = "kube-system"
  create_namespace = true
  wait             = true
  version          = "0.1.0"
  values = [
    yamlencode({
      manifests = [
        {
          apiVersion = "apps/v1"
          kind       = "DaemonSet"
          metadata = {
            name = "fuse-device-plugin-daemonset"
          }
          spec = {
            selector = {
              matchLabels = {
                name = "fuse-device-plugin-ds"
              }
            }
            template = {
              metadata = {
                labels = {
                  name = "fuse-device-plugin-ds"
                }
              }
              spec = {
                hostNetwork = true
                containers = [
                  {
                    image = local.container_images.fuse_device_plugin
                    name  = "fuse-device-plugin-ctr"
                    securityContext = {
                      allowPrivilegeEscalation = false
                      capabilities = {
                        drop = [
                          "ALL",
                        ]
                      },
                    }
                    volumeMounts = [
                      {
                        name      = "device-plugin"
                        mountPath = "/var/lib/kubelet/device-plugins"
                      },
                    ]
                  },
                ]
                volumes = [
                  {
                    name = "device-plugin"
                    hostPath = {
                      path = "/var/lib/kubelet/device-plugins"
                    }
                  },
                ]
                tolerations = [
                  {
                    key      = "node.kubernetes.io/not-ready"
                    operator = "Exists"
                    effect   = "NoExecute"
                  },
                  {
                    key      = "node.kubernetes.io/unreachable"
                    operator = "Exists"
                    effect   = "NoExecute"
                  },
                  {
                    key      = "node.kubernetes.io/disk-pressure"
                    operator = "Exists"
                    effect   = "NoSchedule"
                  },
                  {
                    key      = "node.kubernetes.io/memory-pressure"
                    operator = "Exists"
                    effect   = "NoSchedule"
                  },
                  {
                    key      = "node.kubernetes.io/pid-pressure"
                    operator = "Exists"
                    effect   = "NoSchedule"
                  },
                  {
                    key      = "node.kubernetes.io/unschedulable"
                    operator = "Exists"
                    effect   = "NoSchedule"
                  },
                  {
                    key      = "node-role.kubernetes.io/de"
                    operator = "Exists"
                  },
                ]
              }
            }
          }
        },
      ]
    }),
  ]
}

# amd device plugin #

resource "helm_release" "amd-gpu" {
  name       = "amd-gpu"
  repository = "https://radeonopencompute.github.io/k8s-device-plugin/"
  chart      = "amd-gpu"
  namespace  = "kube-system"
  wait       = false
  version    = "0.8.0"
  values = [
    yamlencode({
      tolerations = [
        {
          key      = "node-role.kubernetes.io/de"
          operator = "Exists"
        },
      ]
    }),
  ]
}

# nvidia device plugin #

resource "helm_release" "nvidia-device-plugin" {
  name       = "nvidia-device-plugin"
  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  namespace  = "kube-system"
  wait       = false
  version    = "0.14.1"
  values = [
    yamlencode({
      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [
              {
                matchExpressions = [
                  {
                    key      = "nvidia"
                    operator = "Exists"
                  },
                ]
              },
            ]
          }
        }
      }
      tolerations = [
        {
          key      = "node-role.kubernetes.io/de"
          operator = "Exists"
        },
      ]
    }),
  ]
}
