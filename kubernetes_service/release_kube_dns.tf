resource "helm_release" "kube-dns-rbac" {
  name             = "${local.endpoints.kube_dns.name}-rbac"
  namespace        = local.endpoints.kube_dns.namespace
  chart            = "../helm-wrapper"
  create_namespace = true
  wait             = false
  wait_for_jobs    = false
  max_history      = 2
  timeout          = local.kubernetes.helm_release_timeout
  values = [
    yamlencode({
      manifests = [
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
      ]
    }),
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
        }
      }
      service = {
        clusterIP         = local.services.cluster_dns.ip
        loadBalancerIP    = local.services.external_dns.ip
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
          image = local.container_images.external_dns
          args = [
            "--source=service",
            "--source=ingress",
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
            initialDelaySeconds = 10
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
          image = local.container_images.etcd
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
    })
  ]
}