resource "helm_release" "kube-dns" {
  name             = "kube-dns"
  namespace        = "kube-system"
  repository       = "https://coredns.github.io/helm"
  chart            = "coredns"
  create_namespace = true
  wait             = true
  wait_for_jobs    = false
  version          = "1.47.0"
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
      service = {
        clusterIP = local.networks.kubernetes_service.vips.kube-dns
      }
      affinity = {
        podAntiAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = [
            {
              labelSelector = {
                matchExpressions = [
                  {
                    key      = "app.kubernetes.io/instance"
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
              parameters = "${local.domains.public} ${local.networks.service.vips.k8s-gateway}"
            },
            {
              name       = "forward"
              parameters = "${local.domains.kubernetes} ${local.networks.service.vips.k8s-gateway}"
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